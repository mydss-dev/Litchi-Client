import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_identity.dart';
import '../shared/models/app_models.dart';
import '../shared/services/android_core_manager.dart';
import '../shared/services/core_manager.dart';
import '../shared/services/local_port_allocator.dart';
import '../shared/services/macos_tun_kill_switch.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/mihomo_api_client.dart';
import '../shared/services/mihomo_config.dart';
import '../shared/services/mixed_proxy_port_verifier.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/tun_interface_verifier.dart';
import '../shared/services/windows_tun_kill_switch.dart';
import 'core_connection_request.dart';
import 'core_error_message_service.dart';

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

class CoreController extends ChangeNotifier {
  final CoreManager _core = CoreManager();
  final AndroidCoreManager _androidCore = AndroidCoreManager();
  StreamSubscription<CoreState>? _sub;
  StreamSubscription<String>? _logSub;
  StreamSubscription<AndroidCoreStatusEvent>? _androidStatusSub;

  DateTime? _connectedAt;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _coreError = '';
  int _apiPort = MihomoConfig.defaultApiPort;
  int _activeProxyPort = 7890;
  NetworkMode _activeNetworkMode = NetworkMode.system;
  Set<String> _activeTunInterfaces = const {};

  bool _disposed = false;
  bool _connectionToggleInFlight = false;
  DateTime? _lastConnectionToggleAt;
  static const Duration _connectionToggleCooldown = Duration(milliseconds: 800);

  Future<Map<String, int>>? _groupTestInFlight;

  bool _killSwitchEnabled = false;

  final ValueNotifier<int> upBpsNotifier = ValueNotifier(0);
  final ValueNotifier<int> downBpsNotifier = ValueNotifier(0);
  StreamSubscription<({int upBps, int downBps})>? _trafficSub;

  final _logs = <String>[];
  static const _maxLogs = 500;

  ConnectionStatus get connectionStatus => _status;
  bool get isRunning => _status == ConnectionStatus.connected;
  bool get coreRunning => _status == ConnectionStatus.connected;
  bool get coreConnecting =>
      _status == ConnectionStatus.connecting ||
      _status == ConnectionStatus.disconnecting;

  bool get connectionActionLocked =>
      coreConnecting ||
      _connectionToggleInFlight ||
      _isConnectionToggleCoolingDown;

  bool get coreProcessRunning =>
      Platform.isAndroid ? _androidCore.isRunning : _core.isRunning;
  bool get quickTileDisconnected =>
      Platform.isAndroid && _androidCore.quickTileDisconnected;
  String get coreError => _coreError;
  int get activeProxyPort => _activeProxyPort;
  int get upBps => upBpsNotifier.value;
  int get downBps => downBpsNotifier.value;
  Stream<String> get logStream => _core.logStream;
  List<String> get recentLogs => List.unmodifiable(_logs);
  Duration get connectedDuration => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  Future<bool> setKillSwitchEnabled(bool enabled) async {
    _killSwitchEnabled = enabled;
    if ((!Platform.isWindows && !Platform.isMacOS) ||
        _activeNetworkMode != NetworkMode.tun) {
      return true;
    }
    if (!enabled) {
      await _releaseTunKillSwitch();
      return true;
    }
    if (_status != ConnectionStatus.connected) return true;
    final engaged = await _engageTunKillSwitch();
    if (!engaged) {
      _coreError = CoreErrorMessageService.tunKillSwitchUnavailable;
      notifyListeners();
    }
    return engaged;
  }

  Future<void> init() async {
    if (Platform.isAndroid) {
      _androidStatusSub ??= _androidCore.statusStream.listen(
        _onAndroidCoreStatusChanged,
      );
      await _androidCore.init();
      _apiPort = _androidCore.controllerPort;
      MihomoConfig.restoreApiSecret(_androidCore.controllerSecret);
      if (_androidCore.isVpnRunning) {
        _status = ConnectionStatus.connected;
        _connectedAt = DateTime.now();
        _startTrafficMonitor();
      } else {
        _status = ConnectionStatus.disconnected;
        _connectedAt = null;
      }
      return;
    }
    if (!Platform.isWindows && !Platform.isMacOS) return;
    if (_sub != null || _logSub != null) return;

    if (!_core.isRunning) {
      await CoreManager.cleanupOnStartup();
      await ProxySetter.disableIfStale();
    }

    _sub = _core.stateStream.listen(_onCoreStateChanged);
    _logSub = _core.logStream.listen((line) {
      final ts = DateTime.now().toLocal().toString().substring(11, 19);
      _logs.add('[$ts] $line');
      if (_logs.length > _maxLogs) _logs.removeAt(0);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTrafficMonitor();
    unawaited(_androidStatusSub?.cancel());
    unawaited(_androidCore.dispose());
    unawaited(_sub?.cancel());
    unawaited(_logSub?.cancel());
    _core.dispose();
    unawaited(_releaseTunKillSwitch());
    upBpsNotifier.dispose();
    downBpsNotifier.dispose();
    super.dispose();
  }

  Future<void> shutdown() async {
    if (Platform.isAndroid) {
      await _androidCore.stopCore();
      await _androidStatusSub?.cancel();
      _androidStatusSub = null;
      return;
    }
    if (!Platform.isWindows && !Platform.isMacOS) return;
    await _releaseTunKillSwitch();
    _stopTrafficMonitor();
    await _androidStatusSub?.cancel();
    await _androidCore.dispose();
    await _sub?.cancel();
    await _logSub?.cancel();
    _sub = null;
    _logSub = null;
    // Restore the user's proxy before waiting for the core process. If process
    // shutdown reaches the outer quit timeout, Windows must not be left
    // pointing at a listener that is about to disappear.
    try {
      await ProxySetter.disable(notify: false);
    } catch (_) {
      // Best-effort cleanup during explicit application exit.
    }
    if (_core.isRunning) {
      await _core.stop();
      MihomoApiClient.resetClient();
    }
    _core.dispose();
  }

  Future<void> startCoreOnly(CoreConnectionRequest req) async {
    if (Platform.isAndroid) {
      if (_androidCore.isCoreRunning) return;
      if (req.validNodes.isEmpty) return;

      _apiPort = await _allocateApiPort();
      final config = req.buildConfig(
        overrideNetworkMode: NetworkMode.system,
        apiPort: _apiPort,
      );
      if (config == null) return;
      (config['tun'] as Map<String, dynamic>)['enable'] = false;

      final configJson = MihomoConfig.encodeConfig(config);
      final ok = await _androidCore.startCoreOnly(configJson);
      if (ok) {
        final ready = await _waitForController();
        if (!ready) {
          _coreError = 'Android 核心启动成功但控制接口无响应';
          notifyListeners();
          return;
        }
        await _applyInitialSelection(req);
        _connectedAt = null; // core-only is not "connected"
        notifyListeners();
      }
      return;
    }
    if (_core.isRunning) return;
    if (req.validNodes.isEmpty) return;

    _apiPort = await _allocateApiPort();
    _activeProxyPort = await LocalPortAllocator.choose(
      preferred: req.proxyPort,
    );
    final config = req.buildConfig(
      overrideNetworkMode: NetworkMode.system,
      overrideProxyPort: _activeProxyPort,
      apiPort: _apiPort,
    );
    if (config == null) return;

    try {
      final configPath = await MihomoConfig.writeConfig(config);
      await _core.start(configPath, apiPort: _apiPort);
      if (_core.isRunning) {
        await _applyInitialSelection(req);
        notifyListeners();
      }
    } catch (e) {
      SecureLogger.debug('startCoreOnly: core start failed', e);
    }
  }

  Future<String?> reloadCore(CoreConnectionRequest req) async {
    if (Platform.isAndroid) {
      if (coreConnecting) return null;

      final wasVpnConnected = _status == ConnectionStatus.connected;

      // If core isn't running at all, start it core-only.
      if (!_androidCore.isCoreRunning) {
        await startCoreOnly(req);
        if (wasVpnConnected) return _toggleAndroidConnection(req);
        return null;
      }

      // Core is running — reload config via API to avoid full restart.
      final vpnConfig = req.buildConfig(
        overrideNetworkMode: NetworkMode.tun,
        apiPort: _apiPort,
      );
      if (vpnConfig == null) return null;

      // Core-only config: same as VPN but with TUN disabled.
      final coreConfig = Map<String, dynamic>.from(vpnConfig);
      coreConfig['tun'] = {'enable': false};

      final ok = await _androidCore.reloadConfig(
        MihomoConfig.encodeConfig(coreConfig),
      );
      if (!ok) {
        _coreError = CoreErrorMessageService.androidStartFailure(
          _androidCore.lastError,
        );
        notifyListeners();
        return _coreError;
      }
      await _applyInitialSelection(req);
      // If VPN was connected, restart it with the full TUN config.
      if (wasVpnConnected) {
        await _androidCore.stopVpn();
        final vpnOk = await _androidCore.startVpn(
          MihomoConfig.encodeConfig(vpnConfig),
        );
        if (!vpnOk) {
          _coreError = CoreErrorMessageService.androidStartFailure(
            _androidCore.lastError,
          );
          _status = ConnectionStatus.error;
          notifyListeners();
          return _coreError;
        }
      }
      return null;
    }

    if (coreConnecting) return null;

    final wasConnected = _status == ConnectionStatus.connected;
    final hadProcess = _core.isRunning;
    if (!hadProcess) {
      await startCoreOnly(req);
      return null;
    }

    _status = wasConnected
        ? ConnectionStatus.disconnecting
        : ConnectionStatus.disconnected;
    notifyListeners();
    _stopTrafficMonitor();
    try {
      await ProxySetter.disable(notify: false);
    } catch (_) {
      // intentional: best-effort cleanup during stop, failure is safe to ignore
    }
    await _core.stop();
    MihomoApiClient.resetClient();
    _connectedAt = null;
    _coreError = '';
    _status = ConnectionStatus.disconnected;
    notifyListeners();

    if (wasConnected) return toggleConnection(req);
    await startCoreOnly(req);
    return null;
  }

  Future<String?> toggleConnection(CoreConnectionRequest req) async {
    if (!_beginConnectionToggle()) return null;
    try {
      return await _toggleConnection(req);
    } finally {
      _endConnectionToggle();
    }
  }

  Future<String?> _toggleConnection(CoreConnectionRequest req) async {
    if (Platform.isAndroid) return _toggleAndroidConnection(req);
    if (coreConnecting) return null;

    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.disconnecting;
      notifyListeners();
      _stopTrafficMonitor();
      await ProxySetter.disable();
      if (req.networkMode == NetworkMode.tun) {
        await _core.stop();
        MihomoApiClient.resetClient();
        await _releaseTunKillSwitch();
      }
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return null;
    }

    if (req.validNodes.isEmpty) {
      _coreError = CoreErrorMessageService.noAvailableNodes;
      notifyListeners();
      return _coreError;
    }

    if (req.networkMode == NetworkMode.system) {
      await _releaseTunKillSwitch();
    }

    if (_core.isRunning && req.networkMode == NetworkMode.system) {
      _status = ConnectionStatus.connecting;
      _coreError = '';
      notifyListeners();
      try {
        final switched = await MihomoApiClient.switchProxy(
          req.selectedTag,
          apiPort: _apiPort,
        );
        if (!switched) throw StateError('switch proxy failed');
        if (!await MixedProxyPortVerifier.waitUntilReady(
          port: _activeProxyPort,
        )) {
          await ProxySetter.disable();
          await _core.stop();
          MihomoApiClient.resetClient();
          _coreError = CoreErrorMessageService.proxyPortUnavailable;
          _status = ConnectionStatus.error;
          notifyListeners();
          return _coreError;
        }
        await ProxySetter.enable(port: _activeProxyPort);
        _connectedAt = DateTime.now();
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } catch (e) {
        SecureLogger.debug('connect: proxy enable or port ready failed', e);
        _coreError = CoreErrorMessageService.restartClient;
        _status = ConnectionStatus.error;
      }
      notifyListeners();
      return _coreError.isNotEmpty ? _coreError : null;
    }

    if (_core.isRunning) await _core.stop();
    if (req.networkMode == NetworkMode.tun) await ProxySetter.disable();

    _apiPort = await _allocateApiPort();
    _activeProxyPort = await LocalPortAllocator.choose(
      preferred: req.proxyPort,
    );
    if (_activeProxyPort != req.proxyPort) {
      SecureLogger.debug(
        '首选代理端口 ${req.proxyPort} 已被占用，'
        '本次自动切换到 $_activeProxyPort',
      );
    }
    final config = req.buildConfig(
      overrideProxyPort: _activeProxyPort,
      apiPort: _apiPort,
    );
    if (config == null) {
      _coreError = CoreErrorMessageService.configBuildFailed;
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      final existingMacTunInterfaces =
          req.networkMode == NetworkMode.tun && Platform.isMacOS
          ? await TunInterfaceVerifier.matchingInterfaceNames(
              interfaceName: 'utun',
              matchPrefix: true,
            )
          : const <String>{};
      final configPath = await MihomoConfig.writeConfig(config);
      await _core.start(
        configPath,
        apiPort: _apiPort,
        elevateMacTun: Platform.isMacOS && req.networkMode == NetworkMode.tun,
      );

      if (_core.isRunning) {
        await _applyInitialSelection(req);
        if (req.networkMode == NetworkMode.system &&
            !await MixedProxyPortVerifier.waitUntilReady(
              port: _activeProxyPort,
            )) {
          _coreError = CoreErrorMessageService.proxyPortUnavailable;
          await _core.stop();
          MihomoApiClient.resetClient();
          _status = ConnectionStatus.error;
          return _coreError;
        }
        if (req.networkMode == NetworkMode.tun) {
          final tunReady = await TunInterfaceVerifier.waitUntilReady(
            interfaceName: Platform.isMacOS
                ? 'utun'
                : AppIdentity.tunInterfaceAlias,
            matchPrefix: Platform.isMacOS,
            excludedNames: existingMacTunInterfaces,
          );
          if (!tunReady) {
            _coreError = CoreErrorMessageService.tunInterfaceUnavailable;
            await _core.stop();
            MihomoApiClient.resetClient();
            await _releaseTunKillSwitch();
            _status = ConnectionStatus.error;
            return _coreError;
          }
          final currentTunInterfaces = Platform.isMacOS
              ? await TunInterfaceVerifier.matchingInterfaceNames(
                  interfaceName: 'utun',
                  matchPrefix: true,
                )
              : <String>{AppIdentity.tunInterfaceAlias};
          _activeTunInterfaces = Platform.isMacOS
              ? currentTunInterfaces.difference(existingMacTunInterfaces)
              : currentTunInterfaces;
          if (_killSwitchEnabled) {
            final protected = await _engageTunKillSwitch();
            if (!protected) {
              _coreError = CoreErrorMessageService.tunKillSwitchUnavailable;
              await _core.stop();
              MihomoApiClient.resetClient();
              await _releaseTunKillSwitch();
              _status = ConnectionStatus.error;
              return _coreError;
            }
          }
        }
        if (req.networkMode == NetworkMode.system) {
          await ProxySetter.enable(port: _activeProxyPort);
        }
        _activeNetworkMode = req.networkMode;
        _connectedAt = DateTime.now();
        _coreError = '';
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } else {
        _coreError = CoreErrorMessageService.processStartFailure(
          _core.lastError,
        );
        _status = ConnectionStatus.error;
      }
    } catch (e) {
      _coreError = CoreErrorMessageService.windowsStartException(e);
      _status = ConnectionStatus.error;
    } finally {
      notifyListeners();
    }
    return _coreError.isNotEmpty ? _coreError : null;
  }

  Future<String?> _toggleAndroidConnection(CoreConnectionRequest req) async {
    if (coreConnecting) return null;

    // ── Disconnect: stop VPN, core stays running ─────────────────────────
    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.disconnecting;
      notifyListeners();
      await _androidCore.stopVpn();
      _stopTrafficMonitor();
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return null;
    }

    if (req.validNodes.isEmpty) {
      _coreError = CoreErrorMessageService.noAvailableNodes;
      notifyListeners();
      return _coreError;
    }

    if (!_androidCore.isCoreRunning) {
      _apiPort = await _allocateApiPort();
    }
    final config = req.buildConfig(
      overrideNetworkMode: NetworkMode.tun,
      apiPort: _apiPort,
    );

    if (config == null) {
      _coreError = CoreErrorMessageService.configBuildFailed;
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      // Step 1: start (or reuse) core-only so external-controller is up.
      if (!_androidCore.isCoreRunning) {
        final coreConfig = Map<String, dynamic>.from(config);
        coreConfig['tun'] = {'enable': false};
        final coreOk = await _androidCore.startCoreOnly(
          MihomoConfig.encodeConfig(coreConfig),
        );
        if (!coreOk) {
          _coreError = CoreErrorMessageService.androidStartFailure(
            _androidCore.lastError,
          );
          _status = ConnectionStatus.error;
          notifyListeners();
          return _coreError;
        }
        final ready = await _waitForController();
        if (!ready) {
          _coreError = 'Android 核心启动成功但控制接口无响应';
          _status = ConnectionStatus.error;
          notifyListeners();
          return _coreError;
        }
        await _applyInitialSelection(req);
      }

      // Step 2: start VPN layer on top.
      final configJson = MihomoConfig.encodeConfig(config);
      final ok = await _androidCore.startVpn(configJson);
      if (ok) {
        _connectedAt = DateTime.now();
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } else {
        _coreError = CoreErrorMessageService.androidStartFailure(
          _androidCore.lastError,
        );
        _status = ConnectionStatus.error;
      }
    } catch (e) {
      _coreError = '$e';
      _status = ConnectionStatus.error;
    } finally {
      notifyListeners();
    }

    return _coreError.isNotEmpty ? _coreError : null;
  }

  Future<void> stopAndReset() async {
    if (Platform.isAndroid) {
      await _androidCore.stopCore();
      _stopTrafficMonitor();
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      return;
    }
    _stopTrafficMonitor();
    await _releaseTunKillSwitch();
    // Mark this as an intentional stop before the core exits, so the stopped
    // event is not misread as an unexpected core death by _onCoreStateChanged.
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      _status = ConnectionStatus.disconnecting;
    }
    if (_core.isRunning) {
      await _core.stop();
      MihomoApiClient.resetClient();
    }
    await ProxySetter.disable();
    _connectedAt = null;
    _coreError = '';
    _status = ConnectionStatus.disconnected;
  }

  Future<bool> switchNode(NodeModel node) async {
    final tag = MihomoConfig.nodeTagFor(node);
    final changed = Platform.isAndroid
        ? await _androidCore.switchProxy(MihomoConfig.selectorTag, tag)
        : await MihomoApiClient.switchProxy(tag, apiPort: _apiPort);
    if (changed) {
      await _closeConnections();
    }
    return changed;
  }

  Future<bool> switchToAuto() async {
    final changed = Platform.isAndroid
        ? await _androidCore.switchProxy(
            MihomoConfig.selectorTag,
            MihomoConfig.autoSelectTag,
          )
        : await MihomoApiClient.switchProxy(
            MihomoConfig.autoSelectTag,
            apiPort: _apiPort,
          );
    if (changed) {
      await _closeConnections();
    }
    return changed;
  }

  Future<bool> _closeConnections() {
    if (Platform.isAndroid) {
      return _androidCore.closeConnections();
    }
    return MihomoApiClient.closeConnections(apiPort: _apiPort);
  }

  Future<bool> setMode(ProxyMode proxyMode) async {
    if (!coreProcessRunning) return true;
    bool changed;
    if (Platform.isAndroid) {
      changed = await _androidCore.setMode(proxyMode.clashValue);
      if (!changed) return false;
      if (proxyMode == ProxyMode.global) {
        changed = await _androidCore.switchProxy(
          MihomoConfig.globalTag,
          MihomoConfig.selectorTag,
        );
      }
    } else {
      changed = await MihomoApiClient.setMode(
        proxyMode.clashValue,
        apiPort: _apiPort,
      );
    }
    if (changed) {
      await _closeConnections();
    }
    return changed;
  }

  Future<void> fixProxy(
    int proxyPort, {
    NetworkMode networkMode = NetworkMode.system,
  }) async {
    if (!Platform.isWindows && !Platform.isMacOS) return;
    if (_core.isRunning && networkMode == NetworkMode.system) {
      await ProxySetter.enable(port: proxyPort);
    } else {
      await ProxySetter.disable();
    }
  }

  static Future<String> getCoreVersion() async {
    if (Platform.isAndroid) return AndroidCoreManager().version();
    if (!Platform.isWindows && !Platform.isMacOS) return '当前平台暂未接入核心';
    final exe = CoreManager.findExecutable();
    if (exe == null) return '未找到 mihomo 核心';
    Process? process;
    try {
      process = await Process.start(exe, [
        'version',
      ], mode: ProcessStartMode.normal);
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      await process.exitCode.timeout(const Duration(seconds: 3));
      final out = (await stdoutFuture).trim();
      await stderrFuture;
      final m = RegExp(
        r'(?:Mihomo Meta|mihomo) ([\d.]+\S*)',
        caseSensitive: false,
      ).firstMatch(out);
      return m?.group(1) ?? out.split('\n').first.trim();
    } on TimeoutException {
      process?.kill();
      try {
        await process?.exitCode.timeout(const Duration(seconds: 1));
      } catch (_) {
        // Best-effort process reap; the initial kill normally completes.
      }
      return '获取超时';
    } catch (e) {
      SecureLogger.debug('detectCoreVersion: version parse failed', e);
      return '获取失败';
    }
  }

  void _startTrafficMonitor() {
    _stopTrafficMonitor();
    _trafficSub = MihomoApiClient.trafficStream(apiPort: _apiPort).listen((t) {
      downBpsNotifier.value = t.downBps;
      upBpsNotifier.value = t.upBps;
    });
  }

  void _stopTrafficMonitor() {
    if (_trafficSub != null) {
      unawaited(_trafficSub!.cancel());
      _trafficSub = null;
    }
    downBpsNotifier.value = 0;
    upBpsNotifier.value = 0;
  }

  /// Coalesces concurrent callers onto a single /group/{}/delay so a double
  /// tap (or a UI test + a background preload firing together) hits the core
  /// only once.  Each caller maps the shared result onto its own node snapshot;
  /// AppController's runId guard discards stale UI updates.
  Future<void> testLatencies(
    List<NodeModel> nodes, {
    required void Function(int idx, NodeModel updated) onResult,
  }) async {
    if (nodes.isEmpty || !coreProcessRunning) return;

    final history = await (_groupTestInFlight ??= _runGroupTest());

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final ms = history[MihomoConfig.nodeTagFor(node)] ?? 9999;
      onResult(i, node.copyWith(latency: ms));
    }
  }

  Future<Map<String, int>> _runGroupTest() async {
    try {
      return await MihomoApiClient.testGroup(apiPort: _apiPort);
    } finally {
      _groupTestInFlight = null;
    }
  }

  Future<void> _applyInitialSelection(CoreConnectionRequest req) async {
    if (Platform.isAndroid) {
      await _androidCore.switchProxy(MihomoConfig.selectorTag, req.selectedTag);
      if (req.proxyMode == ProxyMode.global) {
        await _androidCore.setMode('global');
        await _androidCore.switchProxy(
          MihomoConfig.globalTag,
          MihomoConfig.selectorTag,
        );
      }
      return;
    }
    await MihomoApiClient.switchProxy(req.selectedTag, apiPort: _apiPort);
    if (req.proxyMode == ProxyMode.global) {
      await MihomoApiClient.setMode('global', apiPort: _apiPort);
    }
  }

  Future<bool> _waitForController() async {
    for (var i = 0; i < 30; i++) {
      if (await MihomoApiClient.isReady(apiPort: _apiPort)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  bool get _isConnectionToggleCoolingDown {
    final last = _lastConnectionToggleAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _connectionToggleCooldown;
  }

  bool _beginConnectionToggle() {
    if (connectionActionLocked) return false;
    _connectionToggleInFlight = true;
    notifyListeners();
    return true;
  }

  void _endConnectionToggle() {
    _lastConnectionToggleAt = DateTime.now();
    _connectionToggleInFlight = false;
    notifyListeners();
    unawaited(
      Future<void>.delayed(_connectionToggleCooldown, () {
        if (!_disposed && !_connectionToggleInFlight) notifyListeners();
      }),
    );
  }

  Future<int> _allocateApiPort() async {
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      return socket.port;
    } catch (e) {
      SecureLogger.debug('_allocatePort: bind failed, using default', e);
      return MihomoConfig.defaultApiPort;
    } finally {
      await socket?.close();
    }
  }

  void _onCoreStateChanged(CoreState state) {
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_status == ConnectionStatus.connected ||
            _status == ConnectionStatus.connecting)) {
      // A clean, user-initiated disconnect always moves the status to
      // disconnecting *before* stopping the core, so reaching here while the
      // status is still connected/connecting means the core died
      // unexpectedly. Surface it as an error instead of a silent
      // "disconnected": in TUN mode the tunnel interface is now gone and
      // traffic would otherwise fall back to the physical link with the user
      // believing they were still protected.
      final wasConnected = _status == ConnectionStatus.connected;
      MihomoApiClient.resetClient();
      _stopTrafficMonitor();
      _connectedAt = null;
      if (state == CoreState.error && _core.lastError.isNotEmpty) {
        _coreError = _core.lastError;
      } else if (_coreError.isEmpty) {
        _coreError = CoreErrorMessageService.unexpectedCoreExit;
      }
      _status = ConnectionStatus.error;
      if (_killSwitchEnabled && wasConnected) {
        if (_activeNetworkMode == NetworkMode.tun) {
          // Keep the Windows WFP or macOS PF session alive. Once the tunnel
          // disappears, direct traffic from the signed-in user remains blocked
          // until reconnect, disconnect, or application exit.
        } else {
          unawaited(ProxySetter.engageKillSwitch());
        }
      } else {
        unawaited(_releaseTunKillSwitch());
        unawaited(ProxySetter.disable());
      }
      notifyListeners();
    }
  }

  Future<bool> _engageTunKillSwitch() {
    if (Platform.isWindows) return WindowsTunKillSwitch.engage();
    if (Platform.isMacOS) {
      return MacOsTunKillSwitch.engage(tunnelInterfaces: _activeTunInterfaces);
    }
    return Future<bool>.value(true);
  }

  Future<void> _releaseTunKillSwitch() async {
    await WindowsTunKillSwitch.release();
    await MacOsTunKillSwitch.release();
    _activeTunInterfaces = const {};
  }

  void _onAndroidCoreStatusChanged(AndroidCoreStatusEvent event) {
    final isVpn = event.layer == AndroidCoreLayer.vpn;
    switch (event.status) {
      case AndroidCoreNativeStatus.starting:
        _coreError = '';
        if (isVpn) _status = ConnectionStatus.connecting;
        break;

      case AndroidCoreNativeStatus.running:
        _coreError = '';
        if (isVpn) {
          _connectedAt = DateTime.now();
          _status = ConnectionStatus.connected;
          _startTrafficMonitor();
        } else {
          // core-only running: core is ready for URLTest, NOT connected.
          if (_status != ConnectionStatus.connected &&
              _status != ConnectionStatus.connecting) {
            _status = ConnectionStatus.disconnected;
            _connectedAt = null;
          }
        }
        break;

      case AndroidCoreNativeStatus.stopping:
        if (isVpn) _status = ConnectionStatus.disconnecting;
        break;

      case AndroidCoreNativeStatus.stopped:
        if (isVpn) {
          _stopTrafficMonitor();
          _connectedAt = null;
          if (_status != ConnectionStatus.error) {
            _status = ConnectionStatus.disconnected;
          }
        }
        break;

      case AndroidCoreNativeStatus.error:
        _coreError = event.error.isNotEmpty
            ? event.error
            : CoreErrorMessageService.androidStartFailed;
        if (isVpn) {
          _stopTrafficMonitor();
          _connectedAt = null;
          _status = ConnectionStatus.error;
        }
        break;
    }
    notifyListeners();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/services/android_core_manager.dart';
import '../shared/services/core_manager.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/mihomo_api_client.dart';
import '../shared/services/mihomo_config.dart';
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

  bool _disposed = false;
  bool _connectionToggleInFlight = false;
  DateTime? _lastConnectionToggleAt;
  static const Duration _connectionToggleCooldown = Duration(milliseconds: 800);

  bool killSwitchEnabled = false;
  bool closeConnectionsOnSwitch = true;

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
  String get coreError => _coreError;
  int get upBps => upBpsNotifier.value;
  int get downBps => downBpsNotifier.value;
  Stream<String> get logStream => _core.logStream;
  List<String> get recentLogs => List.unmodifiable(_logs);
  Duration get connectedDuration => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

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
    _stopTrafficMonitor();
    await _androidStatusSub?.cancel();
    await _androidCore.dispose();
    await _sub?.cancel();
    await _logSub?.cancel();
    _sub = null;
    _logSub = null;
    _core.dispose();
    try {
      await ProxySetter.disable(notify: false);
    } catch (_) {}
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
    final config = req.buildConfig(
      overrideNetworkMode: NetworkMode.system,
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
    } catch (_) {}
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
    } catch (_) {}
    await _core.stop();
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
      if (req.networkMode == NetworkMode.tun) await _core.stop();
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
        await ProxySetter.enable(port: req.proxyPort);
        _connectedAt = DateTime.now();
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } catch (_) {
        _coreError = CoreErrorMessageService.restartClient;
        _status = ConnectionStatus.error;
      }
      notifyListeners();
      return _coreError.isNotEmpty ? _coreError : null;
    }

    _apiPort = await _allocateApiPort();
    final config = req.buildConfig(apiPort: _apiPort);
    if (config == null) {
      _coreError = CoreErrorMessageService.configBuildFailed;
      notifyListeners();
      return _coreError;
    }

    if (_core.isRunning) await _core.stop();
    if (req.networkMode == NetworkMode.tun) await ProxySetter.disable();

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      final configPath = await MihomoConfig.writeConfig(config);
      await _core.start(configPath, apiPort: _apiPort);

      if (_core.isRunning) {
        await _applyInitialSelection(req);
        if (req.networkMode == NetworkMode.system) {
          await ProxySetter.enable(port: req.proxyPort);
        }
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
    if (_core.isRunning) await _core.stop();
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
    if (changed && closeConnectionsOnSwitch) {
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
    if (changed && closeConnectionsOnSwitch) {
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
    if (changed && closeConnectionsOnSwitch) {
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
    try {
      final r = await Process.run(exe, ['version']).timeout(
        const Duration(seconds: 3),
        onTimeout: () => ProcessResult(0, 1, '', ''),
      );
      final out = '${r.stdout}'.trim();
      final m = RegExp(
        r'(?:Mihomo Meta|mihomo) ([\d.]+\S*)',
        caseSensitive: false,
      ).firstMatch(out);
      return m?.group(1) ?? out.split('\n').first.trim();
    } catch (_) {
      return '获取失败';
    }
  }

  Future<String?> exportLogs() async {
    if (_logs.isEmpty) return null;
    try {
      final base =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.systemTemp.path;
      final dir = Directory('$base\\Litchi');
      await dir.create(recursive: true);
      final ts = DateTime.now()
          .toLocal()
          .toString()
          .substring(0, 19)
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
      final file = File('${dir.path}\\logs-$ts.txt');
      await file.writeAsString(_logs.join('\n'));
      return file.path;
    } catch (_) {
      return null;
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

  Future<void> testLatencies(
    List<NodeModel> nodes, {
    required void Function(int idx, NodeModel updated) onResult,
  }) async {
    if (nodes.isEmpty || !coreProcessRunning) return;

    final history = await MihomoApiClient.testGroup(apiPort: _apiPort);

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final ms = history[MihomoConfig.nodeTagFor(node)] ?? 9999;
      onResult(i, node.copyWith(latency: ms));
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
    } catch (_) {
      return MihomoConfig.defaultApiPort;
    } finally {
      await socket?.close();
    }
  }

  void _onCoreStateChanged(CoreState state) {
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_status == ConnectionStatus.connected ||
            _status == ConnectionStatus.connecting)) {
      final wasConnected = _status == ConnectionStatus.connected;
      _stopTrafficMonitor();
      _connectedAt = null;
      if (state == CoreState.error && _core.lastError.isNotEmpty) {
        _coreError = _core.lastError;
      }
      _status = state == CoreState.error
          ? ConnectionStatus.error
          : ConnectionStatus.disconnected;
      if (killSwitchEnabled && wasConnected) {
        unawaited(ProxySetter.engageKillSwitch());
      } else {
        unawaited(ProxySetter.disable());
      }
      notifyListeners();
    }
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

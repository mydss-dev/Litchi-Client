import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_identity.dart';
import '../shared/models/app_models.dart';
import '../shared/services/android_core_manager.dart';
import '../shared/services/core_state.dart';
import '../shared/services/local_port_allocator.dart';
import '../shared/services/macos_tun_kill_switch.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/clash_api_client.dart';
import '../shared/services/sing_box_config.dart';
import '../shared/services/sing_box_core_manager.dart';
import '../shared/services/tcp_ping_service.dart';
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
  final SingBoxCoreManager _core = SingBoxCoreManager();
  final AndroidCoreManager _androidCore = AndroidCoreManager();
  StreamSubscription<CoreState>? _sub;
  StreamSubscription<String>? _logSub;
  StreamSubscription<String>? _windowsTunExitSub;
  StreamSubscription<AndroidCoreStatusEvent>? _androidStatusSub;

  DateTime? _connectedAt;
  DateTime? _connectingStartedAt;
  DateTime? _disconnectingStartedAt;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _coreError = '';
  int _apiPort = SingBoxConfig.defaultApiPort;
  int _activeProxyPort = 7890;
  NetworkMode _activeNetworkMode = NetworkMode.system;
  Set<String> _activeTunInterfaces = const {};

  /// Random secret guarding the main core's clash_api. Generated once per app
  /// session and reused across main-core reloads/restarts.
  String _apiSecret = '';

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
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    if (_sub != null || _logSub != null) return;

    if (!_core.isRunning) {
      await SingBoxCoreManager.cleanupOnStartup();
      if (Platform.isWindows) {
        await _core.cleanupWindowsTunOnStartup();
      }
      await ProxySetter.disableIfStale();
    }

    _sub = _core.stateStream.listen(_onCoreStateChanged);
    _logSub = _core.logStream.listen((line) {
      final ts = DateTime.now().toLocal().toString().substring(11, 19);
      _logs.add('[$ts] $line');
      if (_logs.length > _maxLogs) _logs.removeAt(0);
    });
    if (Platform.isWindows) {
      _windowsTunExitSub ??= _core.windowsTunExitStream.listen(
        _onWindowsTunUnexpectedStop,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTrafficMonitor();
    unawaited(_androidStatusSub?.cancel());
    unawaited(_androidCore.dispose());
    unawaited(_sub?.cancel());
    unawaited(_logSub?.cancel());
    unawaited(_windowsTunExitSub?.cancel());
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
    if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
    if (Platform.isWindows) {
      await _core.stopWindowsTun();
    }
    await _releaseTunKillSwitch();
    _stopTrafficMonitor();
    await _androidStatusSub?.cancel();
    await _androidCore.dispose();
    await _sub?.cancel();
    await _logSub?.cancel();
    await _windowsTunExitSub?.cancel();
    _sub = null;
    _logSub = null;
    _windowsTunExitSub = null;
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
      ClashApiClient.resetClient();
    }
    _core.dispose();
  }

  Future<void> startCoreOnly(CoreConnectionRequest req) async {
    _ensureApiSecret();
    if (Platform.isAndroid) {
      if (_androidCore.isCoreRunning) return;
      if (req.validNodes.isEmpty) return;

      _apiPort = await _allocateApiPort();
      final config = req.buildSingBoxConfig(
        overrideNetworkMode: NetworkMode.system,
        apiPort: _apiPort,
        apiSecret: _apiSecret,
      );
      if (config == null) return;
      final configJson = SingBoxConfig.encodeConfig(config);
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
    // Windows always runs the main core without TUN. The privileged service is
    // attached later only when the user actually connects in TUN mode.
    final config = req.buildSingBoxConfig(
      overrideNetworkMode: NetworkMode.system,
      overrideProxyPort: _activeProxyPort,
      apiPort: _apiPort,
      apiSecret: _apiSecret,
    );
    if (config == null) return;

    try {
      final configPath = await SingBoxConfig.writeConfig(config);
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
    _ensureApiSecret();
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
      final vpnConfig = req.buildSingBoxConfig(
        overrideNetworkMode: NetworkMode.tun,
        apiPort: _apiPort,
        apiSecret: _apiSecret,
      );
      if (vpnConfig == null) return null;

      // Core-only config: same as VPN but with TUN disabled.
      final coreConfig = req.buildSingBoxConfig(
        overrideNetworkMode: NetworkMode.system,
        apiPort: _apiPort,
        apiSecret: _apiSecret,
      );
      if (coreConfig == null) return null;

      final ok = await _androidCore.reloadConfig(
        SingBoxConfig.encodeConfig(coreConfig),
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
          SingBoxConfig.encodeConfig(vpnConfig),
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

    if (Platform.isWindows) {
      final coreConfig = req.buildSingBoxConfig(
        overrideNetworkMode: NetworkMode.system,
        overrideProxyPort: _activeProxyPort,
        apiPort: _apiPort,
        apiSecret: _apiSecret,
      );
      if (coreConfig == null) {
        _coreError = CoreErrorMessageService.configBuildFailed;
        notifyListeners();
        return _coreError;
      }
      final reloaded = await ClashApiClient.reloadConfig(
        SingBoxConfig.encodeConfig(coreConfig),
        apiPort: _apiPort,
      );
      if (!reloaded) {
        _coreError = CoreErrorMessageService.restartClient;
        notifyListeners();
        return _coreError;
      }
      await _applyInitialSelection(req);
      if (wasConnected && req.networkMode != _activeNetworkMode) {
        final switched = await _switchWindowsNetworkLayer(req);
        if (switched != null) return switched;
      }
      _coreError = '';
      notifyListeners();
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
    ClashApiClient.resetClient();
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

  /// Keeps the UI in "connecting" for at least ~1.5s so the power-button halo
  /// has time to spin before flipping to "connected". Core setup itself is not
  /// delayed — only the visible state transition, which otherwise completes in
  /// tens of milliseconds and reads as an abrupt instant switch.
  Future<void> _holdConnectingMinimum() async {
    final started = _connectingStartedAt;
    if (started == null) return;
    const minDuration = Duration(milliseconds: 1500);
    final remaining = minDuration - DateTime.now().difference(started);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  /// Mirrors [_holdConnectingMinimum] for the teardown path, but shorter: the
  /// core stops in tens of milliseconds, so this keeps "disconnecting" visible
  /// just long enough for the power-button ring to spin once before the flip.
  Future<void> _holdDisconnectingMinimum() async {
    final started = _disconnectingStartedAt;
    if (started == null) return;
    const minDuration = Duration(milliseconds: 700);
    final remaining = minDuration - DateTime.now().difference(started);
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }

  Future<String?> _toggleConnection(CoreConnectionRequest req) async {
    _ensureApiSecret();
    if (Platform.isAndroid) return _toggleAndroidConnection(req);
    if (coreConnecting) return null;

    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.disconnecting;
      _disconnectingStartedAt = DateTime.now();
      notifyListeners();
      _stopTrafficMonitor();
      await ProxySetter.disable();
      if (_activeNetworkMode == NetworkMode.tun) {
        if (Platform.isWindows) {
          final stopped = await _core.stopWindowsTun();
          if (!stopped) {
            _coreError = _core.lastError.isEmpty
                ? 'Windows TUN 服务停止失败，为避免直连泄漏已保持保护状态'
                : _core.lastError;
            _status = ConnectionStatus.error;
            notifyListeners();
            return _coreError;
          }
        } else {
          await _core.stop();
          ClashApiClient.resetClient();
        }
        await _releaseTunKillSwitch();
      }
      _connectedAt = null;
      _coreError = '';
      await _holdDisconnectingMinimum();
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return null;
    }

    if (req.validNodes.isEmpty) {
      _coreError = CoreErrorMessageService.noAvailableNodes;
      _status = ConnectionStatus.error;
      notifyListeners();
      return _coreError;
    }

    if (req.networkMode == NetworkMode.system) {
      await _releaseTunKillSwitch();
    }

    if (_core.isRunning && req.networkMode == NetworkMode.system) {
      _status = ConnectionStatus.connecting;
      _connectingStartedAt = DateTime.now();
      _coreError = '';
      notifyListeners();
      try {
        final switched = await ClashApiClient.switchProxy(
          req.selectedSingBoxTag,
          group: SingBoxConfig.selectorTag,
          apiPort: _apiPort,
        );
        if (!switched) throw StateError('switch proxy failed');
        if (!await MixedProxyPortVerifier.waitUntilReady(
          port: _activeProxyPort,
        )) {
          await ProxySetter.disable();
          await _core.stop();
          ClashApiClient.resetClient();
          _coreError = CoreErrorMessageService.proxyPortUnavailable;
          _status = ConnectionStatus.error;
          notifyListeners();
          return _coreError;
        }
        await ProxySetter.enable(port: _activeProxyPort);
        _activeNetworkMode = NetworkMode.system;
        await _holdConnectingMinimum();
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

    if (Platform.isWindows && req.networkMode == NetworkMode.tun) {
      _status = ConnectionStatus.connecting;
      _connectingStartedAt = DateTime.now();
      _coreError = '';
      notifyListeners();
      try {
        await ProxySetter.disable();
        if (!_core.isRunning) {
          await startCoreOnly(req);
        }
        if (!_core.isRunning) {
          _coreError = CoreErrorMessageService.processStartFailure(
            _core.lastError,
          );
          _status = ConnectionStatus.error;
          return _coreError;
        }
        final switched = await ClashApiClient.switchProxy(
          req.selectedSingBoxTag,
          group: SingBoxConfig.selectorTag,
          apiPort: _apiPort,
        );
        if (!switched) {
          _coreError = CoreErrorMessageService.restartClient;
          _status = ConnectionStatus.error;
          return _coreError;
        }
        final tunError = await _activateWindowsTunLayer();
        if (tunError != null) {
          _coreError = tunError;
          _status = ConnectionStatus.error;
          return _coreError;
        }
        _activeNetworkMode = NetworkMode.tun;
        await _holdConnectingMinimum();
        _connectedAt = DateTime.now();
        _coreError = '';
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } catch (e) {
        SecureLogger.debug('Windows TUN connect failed', e);
        await _core.stopWindowsTun();
        await _releaseTunKillSwitch();
        _coreError = CoreErrorMessageService.windowsStartException(e);
        _status = ConnectionStatus.error;
      } finally {
        notifyListeners();
      }
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
    final config = req.buildSingBoxConfig(
      overrideProxyPort: _activeProxyPort,
      apiPort: _apiPort,
      apiSecret: _apiSecret,
    );
    if (config == null) {
      _coreError = CoreErrorMessageService.configBuildFailed;
      _status = ConnectionStatus.error;
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _connectingStartedAt = DateTime.now();
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
      final configPath = await SingBoxConfig.writeConfig(config);
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
          ClashApiClient.resetClient();
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
            ClashApiClient.resetClient();
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
              ClashApiClient.resetClient();
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
        await _holdConnectingMinimum();
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

  Future<String?> _activateWindowsTunLayer() async {
    if (!await MixedProxyPortVerifier.waitUntilReady(port: _activeProxyPort)) {
      return CoreErrorMessageService.proxyPortUnavailable;
    }
    final tunProfile = SingBoxConfig.tunRouteProfile(isWindows: true);
    final started = await _core.startWindowsTun(
      mainProxyPort: _activeProxyPort,
      mtu: tunProfile.mtu,
      strictRoute: tunProfile.strictRoute,
      stack: 'system',
    );
    if (!started) {
      return _core.lastError.isEmpty
          ? CoreErrorMessageService.tunInterfaceUnavailable
          : _core.lastError;
    }
    final tunReady = await TunInterfaceVerifier.waitUntilReady(
      interfaceName: AppIdentity.tunInterfaceAlias,
    );
    if (!tunReady) {
      await _core.stopWindowsTun();
      return CoreErrorMessageService.tunInterfaceUnavailable;
    }
    _activeTunInterfaces = <String>{AppIdentity.tunInterfaceAlias};
    if (_killSwitchEnabled) {
      final protected = await _engageTunKillSwitch();
      if (!protected) {
        await _core.stopWindowsTun();
        await _releaseTunKillSwitch();
        return CoreErrorMessageService.tunKillSwitchUnavailable;
      }
    }
    return null;
  }

  Future<String?> _switchWindowsNetworkLayer(CoreConnectionRequest req) async {
    if (!Platform.isWindows || _status != ConnectionStatus.connected) {
      return null;
    }
    if (req.networkMode == NetworkMode.tun) {
      await ProxySetter.disable();
      final error = await _activateWindowsTunLayer();
      if (error != null) {
        _coreError = error;
        _status = ConnectionStatus.error;
        notifyListeners();
        return error;
      }
    } else {
      final stopped = await _core.stopWindowsTun();
      if (!stopped) {
        _coreError = _core.lastError.isEmpty
            ? 'Windows TUN 服务停止失败，为避免直连泄漏已保持保护状态'
            : _core.lastError;
        _status = ConnectionStatus.error;
        notifyListeners();
        return _coreError;
      }
      await _releaseTunKillSwitch();
      await ProxySetter.enable(port: _activeProxyPort);
    }
    _activeNetworkMode = req.networkMode;
    return null;
  }

  Future<String?> _toggleAndroidConnection(CoreConnectionRequest req) async {
    _ensureApiSecret();
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
      _status = ConnectionStatus.error;
      notifyListeners();
      return _coreError;
    }

    if (!_androidCore.isCoreRunning) {
      _apiPort = await _allocateApiPort();
    }
    final config = req.buildSingBoxConfig(
      overrideNetworkMode: NetworkMode.tun,
      apiPort: _apiPort,
      apiSecret: _apiSecret,
    );

    if (config == null) {
      _coreError = CoreErrorMessageService.configBuildFailed;
      _status = ConnectionStatus.error;
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      // Step 1: start (or reuse) core-only so external-controller is up.
      if (!_androidCore.isCoreRunning) {
        final coreConfig = req.buildSingBoxConfig(
          overrideNetworkMode: NetworkMode.system,
          apiPort: _apiPort,
          apiSecret: _apiSecret,
        );
        if (coreConfig == null) {
          _coreError = CoreErrorMessageService.configBuildFailed;
          _status = ConnectionStatus.error;
          return _coreError;
        }
        final coreOk = await _androidCore.startCoreOnly(
          SingBoxConfig.encodeConfig(coreConfig),
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
      final configJson = SingBoxConfig.encodeConfig(config);
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
    if (Platform.isWindows) {
      final stopped = await _core.stopWindowsTun();
      if (!stopped) {
        _coreError = _core.lastError.isEmpty
            ? 'Windows TUN 服务停止失败，为避免直连泄漏已保持保护状态'
            : _core.lastError;
        _status = ConnectionStatus.error;
        notifyListeners();
        return;
      }
    }
    await _releaseTunKillSwitch();
    // Mark this as an intentional stop before the core exits, so the stopped
    // event is not misread as an unexpected core death by _onCoreStateChanged.
    if (_status == ConnectionStatus.connected ||
        _status == ConnectionStatus.connecting) {
      _status = ConnectionStatus.disconnecting;
    }
    if (_core.isRunning) {
      await _core.stop();
      ClashApiClient.resetClient();
    }
    await ProxySetter.disable();
    _connectedAt = null;
    _coreError = '';
    _status = ConnectionStatus.disconnected;
  }

  Future<bool> switchNode(NodeModel node) async {
    final tag = SingBoxConfig.nodeTagFor(node);
    final changed = await ClashApiClient.switchProxy(
      tag,
      group: SingBoxConfig.selectorTag,
      apiPort: _apiPort,
    );
    if (changed) {
      await _closeConnections();
    }
    return changed;
  }

  Future<bool> switchToAuto() async {
    final changed = await ClashApiClient.switchProxy(
      SingBoxConfig.autoSelectTag,
      group: SingBoxConfig.selectorTag,
      apiPort: _apiPort,
    );
    if (changed) {
      await _closeConnections();
    }
    return changed;
  }

  Future<bool> _closeConnections() {
    return ClashApiClient.closeConnections(apiPort: _apiPort);
  }

  Future<bool> setMode(ProxyMode proxyMode) async {
    if (!coreProcessRunning) return true;
    bool changed;
    changed = await ClashApiClient.setMode(
      proxyMode.controllerValue,
      apiPort: _apiPort,
    );
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
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return SingBoxCoreManager().version();
    }
    return '当前平台暂未接入核心';
  }

  void _startTrafficMonitor() {
    _stopTrafficMonitor();
    _trafficSub = ClashApiClient.trafficStream(apiPort: _apiPort).listen((t) {
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

  /// Coalesces concurrent callers onto a single latency pass so a double tap
  /// (or a UI test + a background preload firing together) hits the core only
  /// once. Each caller maps the shared result onto its own node snapshot;
  /// AppController's runId guard discards stale UI updates.
  Future<void> testLatencies(
    List<NodeModel> nodes, {
    required void Function(int idx, NodeModel updated) onResult,
  }) async {
    if (nodes.isEmpty || !coreProcessRunning) return;

    final history = await (_groupTestInFlight ??= _runGroupTest(nodes));

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final tag = SingBoxConfig.nodeTagFor(node);
      final ms = history[tag] ?? 9999;
      onResult(i, node.copyWith(latency: ms));
    }
  }

  Future<Map<String, int>> _runGroupTest(List<NodeModel> nodes) async {
    try {
      return await _measureWarmLatencies(nodes);
    } finally {
      _groupTestInFlight = null;
    }
  }

  /// Reports a "warm" per-node latency: the TCP round-trip to the node server,
  /// which matches what Clash / V2RayN show for an in-use node and the browsing
  /// latency users actually feel (~RTT). The core's own delay test is *cold* —
  /// it re-dials the outbound each time, so a Reality node pays its full TLS
  /// handshake on top of TCP, reading ~3× higher than reality.
  ///
  /// End-to-end reachability is still verified per node via the core's single-
  /// proxy delay test, so a node whose Reality handshake is broken (but whose
  /// TCP port still answers) is reported as timed out instead of a misleading
  /// fast RTT. Per-node tests avoid the group endpoint's shared timeout, which
  /// used to blank out healthy nodes queued behind a slow one.
  Future<Map<String, int>> _measureWarmLatencies(List<NodeModel> nodes) async {
    final probes = await Future.wait([
      for (final node in nodes) _probeNode(node),
    ]);
    final result = <String, int>{};
    for (var i = 0; i < nodes.length; i++) {
      result[SingBoxConfig.nodeTagFor(nodes[i])] = probes[i];
    }
    return result;
  }

  /// End-to-end delay (availability) plus a warm TCP RTT for a single node.
  /// Returns 9999 when the core can't proxy through it at all.
  Future<int> _probeNode(NodeModel node) async {
    final tag = SingBoxConfig.nodeTagFor(node);
    final e2eFuture = ClashApiClient.testDelay(tag, apiPort: _apiPort);
    final tcpFuture = _tcpPingNode(node);
    final e2e = await e2eFuture;
    if (e2e == null) {
      return 9999; // broken Reality / unreachable — no fake latency
    }
    final tcp = await tcpFuture;
    return tcp ?? e2e; // UDP-only nodes fall back to the end-to-end delay
  }

  /// TCP round-trip to a node's server, or null when it has no single usable
  /// port to probe (UDP-only protocols, or `server_ports` ranges).
  static Future<int?> _tcpPingNode(NodeModel node) async {
    final outbound = node.rawOutbound;
    if (outbound == null) return null;
    final server = '${outbound['server'] ?? ''}'.trim();
    final port = _probePort(outbound);
    if (server.isEmpty || port == null) return null;
    return TcpPingService.ping(server, port);
  }

  static int? _probePort(Map<String, dynamic> outbound) {
    final port = outbound['server_port'];
    if (port is num && port > 0 && port <= 65535) return port.toInt();
    final ranges = outbound['server_ports'];
    if (ranges is List && ranges.isNotEmpty) {
      final first = ranges.first;
      if (first is num) {
        final value = first.toInt();
        if (value > 0 && value <= 65535) return value;
      }
      if (first is String) {
        final parsed = int.tryParse(first.split('-').first.trim());
        if (parsed != null && parsed > 0 && parsed <= 65535) return parsed;
      }
    }
    return null;
  }

  Future<void> _applyInitialSelection(CoreConnectionRequest req) async {
    await ClashApiClient.switchProxy(
      req.selectedSingBoxTag,
      group: SingBoxConfig.selectorTag,
      apiPort: _apiPort,
    );
    if (req.proxyMode == ProxyMode.global) {
      await ClashApiClient.setMode('global', apiPort: _apiPort);
    }
  }

  Future<bool> _waitForController() async {
    for (var i = 0; i < 30; i++) {
      if (await ClashApiClient.isReady(apiPort: _apiPort)) return true;
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
      return SingBoxConfig.defaultApiPort;
    } finally {
      await socket?.close();
    }
  }

  /// Ensures a session-wide random clash_api secret exists and mirrors it to
  /// [ClashApiClient]. Transport resets deliberately keep this secret intact.
  void _ensureApiSecret() {
    if (_apiSecret.isEmpty) {
      final random = Random.secure();
      const chars =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      _apiSecret = List.generate(
        32,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
    }
    ClashApiClient.apiSecret = _apiSecret;
  }

  void _onCoreStateChanged(CoreState state) {
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_status == ConnectionStatus.connected ||
            _status == ConnectionStatus.connecting)) {
      // A clean, user-initiated disconnect always moves the status to
      // disconnecting *before* stopping the core, so reaching here while the
      // status is still connected/connecting means the core died unexpectedly.
      final wasConnected = _status == ConnectionStatus.connected;
      ClashApiClient.resetClient();
      _stopTrafficMonitor();
      _connectedAt = null;
      if (Platform.isWindows && _activeNetworkMode == NetworkMode.tun) {
        unawaited(_core.stopWindowsTun());
      }
      if (state == CoreState.error && _core.lastError.isNotEmpty) {
        _coreError = _core.lastError;
      } else if (_coreError.isEmpty) {
        _coreError = CoreErrorMessageService.unexpectedCoreExit;
      }
      _status = ConnectionStatus.error;
      if (_killSwitchEnabled && wasConnected) {
        if (_activeNetworkMode == NetworkMode.tun) {
          // Keep the Windows WFP or macOS PF session alive. Once the tunnel
          // disappears, direct traffic remains blocked until explicit cleanup.
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

  void _onWindowsTunUnexpectedStop(String error) {
    if (!Platform.isWindows || _activeNetworkMode != NetworkMode.tun) return;
    if (_status != ConnectionStatus.connected &&
        _status != ConnectionStatus.connecting) {
      return;
    }
    final wasConnected = _status == ConnectionStatus.connected;
    _stopTrafficMonitor();
    _connectedAt = null;
    _coreError = error.isEmpty ? 'Windows TUN 服务意外停止' : error;
    _status = ConnectionStatus.error;
    if (!_killSwitchEnabled || !wasConnected) {
      unawaited(_releaseTunKillSwitch());
    }
    unawaited(ProxySetter.disable());
    notifyListeners();
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

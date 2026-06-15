import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/services/core_manager.dart' show CoreState;
import '../shared/services/proxy_setter.dart';
import '../shared/services/secure_logger.dart';
import '../shared/services/singbox_api_client.dart';
import '../shared/services/singbox_config.dart';
import 'android_core_runtime.dart';
import 'core_connection_request.dart';
import 'core_error_message_service.dart';
import 'core_platform_support.dart';
import 'core_runtime.dart';
import 'desktop_core_runtime.dart';

/// High-level connection lifecycle state exposed to UI.
enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Owns the sing-box process, connection lifecycle, and latency testing.
///
/// Settings values and the node list are passed in at call time to avoid
/// storing references that would create circular dependencies.
class CoreController extends ChangeNotifier {
  final DesktopCoreRuntime _desktopRuntime = DesktopCoreRuntime();
  final AndroidCoreRuntime _androidRuntime = AndroidCoreRuntime();
  StreamSubscription<CoreState>? _sub;
  StreamSubscription<String>? _logSub;

  DateTime? _connectedAt;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _coreError = '';

  // Traffic monitoring (bytes/sec, updated by Clash /traffic stream).
  final ValueNotifier<int> upBpsNotifier = ValueNotifier(0);
  final ValueNotifier<int> downBpsNotifier = ValueNotifier(0);
  StreamSubscription<({int upBps, int downBps})>? _trafficSub;

  // Rolling log buffer — last 500 lines, timestamped.
  final _logs = <String>[];
  static const _maxLogs = 500;

  /// When true, an unexpected core termination engages the proxy kill-switch
  /// (fail-closed) instead of reverting to a direct connection. Kept in sync by
  /// [AppController] from the persisted user setting.
  bool killSwitchEnabled = false;

  ConnectionStatus get connectionStatus => _status;
  bool get isRunning => _status == ConnectionStatus.connected;
  bool get coreRunning => _status == ConnectionStatus.connected;
  bool get coreConnecting =>
      _status == ConnectionStatus.connecting ||
      _status == ConnectionStatus.disconnecting;

  /// True when the sing-box process is alive, regardless of proxy state.
  /// Use this to guard latency tests — the Clash API is available whenever
  /// the process is running, even before the user explicitly connects.
  bool get coreProcessRunning => CorePlatformSupport.processRunningFor(
    isAndroid: CorePlatformSupport.isAndroid,
    androidRunning: _androidRuntime.isRunning,
    desktopRunning: _desktopRuntime.isRunning,
  );
  String get coreError => _coreError;
  int get upBps => upBpsNotifier.value;
  int get downBps => downBpsNotifier.value;
  Stream<String> get logStream => _desktopRuntime.logStream;
  List<String> get recentLogs => List.unmodifiable(_logs);
  Duration get connectedDuration => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  /// Must be called once after construction (inside [AppController.init]).
  /// Kills any orphaned sing-box process and clears a stale system proxy
  /// before subscribing to the core state stream.
  Future<void> init() async {
    if (Platform.isAndroid) {
      await _androidRuntime.init();
      if (_androidRuntime.isRunning) {
        _markConnected(notify: false);
      }
      return;
    }
    if (!CorePlatformSupport.isDesktop) return;
    if (_sub != null || _logSub != null) return;

    await _desktopRuntime.init();

    _sub = _desktopRuntime.stateStream.listen(_onCoreStateChanged);
    _logSub = _desktopRuntime.logStream.listen((line) {
      final ts = DateTime.now().toLocal().toString().substring(11, 19);
      _logs.add('[$ts] ${SecureLogRedactor.redact(line)}');
      if (_logs.length > _maxLogs) _logs.removeAt(0);
    });
  }

  @override
  void dispose() {
    _stopTrafficMonitor();
    _sub?.cancel();
    _logSub?.cancel();
    _desktopRuntime.dispose();
    upBpsNotifier.dispose();
    downBpsNotifier.dispose();
    super.dispose();
  }

  /// Graceful shutdown: kill core process + disable system proxy.
  /// Called from the window-close handler before [windowManager.destroy()].
  Future<void> shutdown() async {
    if (Platform.isAndroid) {
      await _androidRuntime.stop();
      return;
    }
    if (!CorePlatformSupport.isDesktop) return;
    _stopTrafficMonitor();
    await _sub?.cancel();
    await _logSub?.cancel();
    _sub = null;
    _logSub = null;
    _desktopRuntime
        .dispose(); // synchronously kills the process + deletes PID file
    try {
      // Exit path: don't wait on the WinInet broadcast — the registry write
      // alone disables the proxy and keeps shutdown snappy.
      await ProxySetter.disable(notify: false);
    } catch (_) {}
  }

  // ── Connection ────────────────────────────────────────────────────────────

  /// Starts sing-box in the background WITHOUT enabling system proxy or TUN.
  /// Called after login so latency testing works before the user connects.
  /// No-ops if the process is already running.
  Future<void> startCoreOnly(CoreConnectionRequest request) async {
    if (Platform.isAndroid) return;
    if (_desktopRuntime.isRunning) return;
    final validNodes = request.validNodes;
    if (validNodes.isEmpty) return;

    try {
      final ok = await _desktopRuntime.start(
        CoreRuntimeStartPlan(
          request: request,
          overrideNetworkMode: NetworkMode.system,
        ),
      );
      // _status stays disconnected — proxy is NOT enabled yet.
      if (ok) notifyListeners();
    } catch (_) {
      // Background start failure is non-fatal; user can still connect manually.
    }
  }

  /// Rebuilds the sing-box config and restarts the core when it is already
  /// running. If the user was connected, it reconnects with the new config;
  /// otherwise it keeps the core alive in background mode for latency testing.
  Future<String?> reloadCore(CoreConnectionRequest request) async {
    if (Platform.isAndroid) {
      if (coreConnecting || _status != ConnectionStatus.connected) return null;
      await _androidRuntime.stop();
      _markDisconnected(notify: false);
      return _toggleAndroidConnection(request);
    }

    if (coreConnecting) return null;

    final wasConnected = _status == ConnectionStatus.connected;
    final hadProcess = _desktopRuntime.isRunning;
    if (!hadProcess) {
      await startCoreOnly(request);
      return null;
    }

    _setStatus(
      wasConnected
          ? ConnectionStatus.disconnecting
          : ConnectionStatus.disconnected,
    );
    _stopTrafficMonitor();
    try {
      await ProxySetter.disable(notify: false);
    } catch (_) {}
    await _desktopRuntime.stop();
    _markDisconnected();

    if (wasConnected) {
      return toggleConnection(request);
    }

    await startCoreOnly(request);
    return null;
  }

  /// Toggles proxy on/off. When the sing-box process is already running
  /// (started via [startCoreOnly]), connecting only enables the system proxy —
  /// no process restart needed. Disconnecting keeps the process alive so
  /// latency testing continues in the background.
  ///
  /// TUN mode always performs a full restart since the TUN adapter cannot be
  /// toggled without reloading the config.
  Future<String?> toggleConnection(CoreConnectionRequest request) async {
    if (Platform.isAndroid) {
      return _toggleAndroidConnection(request);
    }

    if (coreConnecting) return null;

    // ── DISCONNECT ──────────────────────────────────────────────────────────
    if (_status == ConnectionStatus.connected) {
      _setStatus(ConnectionStatus.disconnecting);
      _stopTrafficMonitor();
      await ProxySetter.disable();
      if (request.networkMode == NetworkMode.tun) {
        // TUN requires a full restart to remove the adapter; stop the process.
        await _desktopRuntime.stop();
      }
      // System proxy mode: keep process alive for background latency testing.
      _markDisconnected();
      return null;
    }

    // ── CONNECT ─────────────────────────────────────────────────────────────
    final validNodes = request.validNodes;
    if (validNodes.isEmpty) {
      return _markError(CoreErrorMessageService.noAvailableNodes);
    }

    final selectedTag = request.selectedTag;

    // Fast path: core already running in system proxy mode — just enable proxy.
    if (_desktopRuntime.isRunning &&
        request.networkMode == NetworkMode.system) {
      _markConnecting();
      try {
        await SingboxApiClient.switchProxy(
          selectedTag,
          apiPort: SingboxConfig.defaultApiPort,
        );
        await ProxySetter.enable(port: request.proxyPort);
        _markConnected(notify: false);
        _startTrafficMonitor();
      } catch (_) {
        _markError(CoreErrorMessageService.restartClient, notify: false);
      }
      notifyListeners();
      return _coreError.isNotEmpty ? _coreError : null;
    }

    // Full start: runtime owns config generation and process launch.
    _markConnecting();

    try {
      final ok = await _desktopRuntime.start(
        CoreRuntimeStartPlan(request: request),
      );

      if (ok) {
        if (request.networkMode == NetworkMode.system) {
          await ProxySetter.enable(port: request.proxyPort);
        }
        _markConnected(notify: false);
        _startTrafficMonitor();
      } else {
        _markError(
          CoreErrorMessageService.processStartFailure(
            _desktopRuntime.lastError,
          ),
          notify: false,
        );
      }
    } catch (e) {
      _markError(
        CoreErrorMessageService.windowsStartException(e),
        notify: false,
      );
    } finally {
      notifyListeners();
    }
    return _coreError.isNotEmpty ? _coreError : null;
  }

  Future<String?> _toggleAndroidConnection(
    CoreConnectionRequest request,
  ) async {
    if (coreConnecting) return null;

    if (_status == ConnectionStatus.connected) {
      _setStatus(ConnectionStatus.disconnecting);
      await _androidRuntime.stop();
      _stopTrafficMonitor();
      _markDisconnected();
      return null;
    }

    final validNodes = request.validNodes;
    if (validNodes.isEmpty) {
      return _markError(CoreErrorMessageService.noAvailableNodes);
    }

    _markConnecting();

    try {
      final ok = await _androidRuntime.start(
        CoreRuntimeStartPlan(
          request: request,
          overrideNetworkMode: NetworkMode.tun,
        ),
      );
      if (ok) {
        _markConnected(notify: false);
      } else {
        _markError(
          CoreErrorMessageService.androidStartFailure(
            _androidRuntime.lastError,
          ),
          notify: false,
        );
      }
    } catch (e) {
      _markError('$e', notify: false);
    } finally {
      notifyListeners();
    }

    return _coreError.isNotEmpty ? _coreError : null;
  }

  /// Stops the core and clears connection state. Called by [AppController.logout].
  void stopAndReset() {
    if (Platform.isAndroid) {
      unawaited(_androidRuntime.stop());
      _markDisconnected(notify: false);
      return;
    }
    if (_desktopRuntime.isRunning) {
      unawaited(_desktopRuntime.stop());
      unawaited(ProxySetter.disable());
    }
    _markDisconnected(notify: false);
  }

  // ── Node switching ────────────────────────────────────────────────────────

  /// Switches the active proxy at runtime without restarting the core.
  /// Returns true if the Clash API accepted the change.
  Future<bool> switchNode(NodeModel node) => SingboxApiClient.switchProxy(
    SingboxConfig.nodeTagFor(node),
    apiPort: SingboxConfig.defaultApiPort,
  );

  /// Switches the PROXY selector to the urltest outbound (自动选择).
  /// sing-box then picks the fastest node internally based on real latency.
  Future<bool> switchToAuto() => SingboxApiClient.switchProxy(
    '自动选择',
    apiPort: SingboxConfig.defaultApiPort,
  );

  // ── Mode switching ────────────────────────────────────────────────────────

  /// Apply [proxyMode] to the running core via Clash API (no restart needed).
  Future<void> setMode(ProxyMode proxyMode) async {
    if (!_desktopRuntime.isRunning) return;
    await SingboxApiClient.setMode(
      proxyMode.clashValue,
      apiPort: SingboxConfig.defaultApiPort,
    );
  }

  // ── Proxy repair ──────────────────────────────────────────────────────────

  /// Force-sync the system proxy to match the current core state.
  Future<void> fixProxy(int proxyPort) async {
    if (!CorePlatformSupport.isDesktop) return;
    if (_desktopRuntime.isRunning) {
      await ProxySetter.enable(port: proxyPort);
    } else {
      await ProxySetter.disable();
    }
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  /// Run `sing-box version` and return the version string.
  static Future<String> getCoreVersion() async {
    if (Platform.isAndroid) {
      return AndroidCoreRuntime().version();
    }
    if (!CorePlatformSupport.isDesktop) return '当前平台暂未接入核心';
    return DesktopCoreRuntime.versionString();
  }

  /// Write the buffered log lines to %LOCALAPPDATA%\Litchi\ and return the path.
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

  // ── Traffic monitoring ────────────────────────────────────────────────────

  void _startTrafficMonitor() {
    _stopTrafficMonitor();
    _trafficSub =
        SingboxApiClient.trafficStream(
          apiPort: SingboxConfig.defaultApiPort,
        ).listen((t) {
          downBpsNotifier.value = t.downBps;
          upBpsNotifier.value = t.upBps;
          // Intentionally no notifyListeners() — speed widgets use
          // ValueListenableBuilder, so the global rebuild is avoided.
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

  void _setStatus(ConnectionStatus status, {bool notify = true}) {
    _status = status;
    if (notify) notifyListeners();
  }

  void _markConnecting({bool notify = true}) {
    _coreError = '';
    _setStatus(ConnectionStatus.connecting, notify: notify);
  }

  void _markConnected({bool notify = true}) {
    _connectedAt = DateTime.now();
    _coreError = '';
    _setStatus(ConnectionStatus.connected, notify: notify);
  }

  void _markDisconnected({bool notify = true}) {
    _connectedAt = null;
    _coreError = '';
    _setStatus(ConnectionStatus.disconnected, notify: notify);
  }

  String _markError(String message, {bool notify = true}) {
    _coreError = message;
    _setStatus(ConnectionStatus.error, notify: notify);
    return _coreError;
  }

  // ── Latency testing ───────────────────────────────────────────────────────

  /// Tests latency for every node in [nodes].
  /// Requires the core to be running — no-ops otherwise.
  ///
  /// Triggers sing-box's urltest group to re-test all nodes concurrently,
  /// then falls back to direct per-node tests if urltest history is empty.
  Future<void> testLatencies(
    List<NodeModel> nodes, {
    required void Function(int idx, NodeModel updated) onResult,
  }) async {
    if (nodes.isEmpty || !_desktopRuntime.isRunning) return;

    final tags = nodes.map(SingboxConfig.nodeTagFor).toList();
    final history = await SingboxApiClient.testAllViaUrltest(
      tags: tags,
      apiPort: SingboxConfig.defaultApiPort,
    );

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final ms = history[SingboxConfig.nodeTagFor(node)] ?? 9999;
      onResult(i, node.copyWith(latency: ms));
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onCoreStateChanged(CoreState state) {
    // React only to unexpected terminations — a deliberate disconnect sets
    // status to disconnecting before stop(), so those are excluded here.
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_status == ConnectionStatus.connected ||
            _status == ConnectionStatus.connecting)) {
      final wasProtecting = _status == ConnectionStatus.connected;
      _stopTrafficMonitor();
      if (state == CoreState.error) {
        _markError(_desktopRuntime.lastError, notify: false);
      } else {
        _markDisconnected(notify: false);
      }
      // Fail-closed: if we were actively tunnelling and the user enabled the
      // kill-switch, blackhole the proxy so traffic can't leak directly.
      if (killSwitchEnabled && wasProtecting) {
        unawaited(ProxySetter.engageKillSwitch());
      } else {
        unawaited(ProxySetter.disable());
      }
      notifyListeners();
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/services/android_core_manager.dart';
import '../shared/services/core_manager.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/singbox_api_client.dart';
import '../shared/services/singbox_config.dart';

/// High-level connection lifecycle state exposed to UI.
enum ConnectionStatus { disconnected, connecting, connected, disconnecting, error }

/// Owns the sing-box process, connection lifecycle, and latency testing.
///
/// Settings values and the node list are passed in at call time to avoid
/// storing references that would create circular dependencies.
class CoreController extends ChangeNotifier {
  final CoreManager _core = CoreManager();
  final AndroidCoreManager _androidCore = AndroidCoreManager();
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

  ConnectionStatus get connectionStatus => _status;
  bool get isRunning => _status == ConnectionStatus.connected;
  bool get coreRunning => _status == ConnectionStatus.connected;
  bool get coreConnecting =>
      _status == ConnectionStatus.connecting ||
      _status == ConnectionStatus.disconnecting;
  /// True when the sing-box process is alive, regardless of proxy state.
  /// Use this to guard latency tests — the Clash API is available whenever
  /// the process is running, even before the user explicitly connects.
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

  /// Must be called once after construction (inside [AppController.init]).
  /// Kills any orphaned sing-box process and clears a stale system proxy
  /// before subscribing to the core state stream.
  Future<void> init() async {
    if (Platform.isAndroid) {
      await _androidCore.init();
      if (_androidCore.isRunning) {
        _status = ConnectionStatus.connected;
        _connectedAt = DateTime.now();
      }
      return;
    }
    if (!Platform.isWindows) return;
    if (_sub != null || _logSub != null) return;

    // If callers started the core before init() finished, do not run startup
    // cleanup because it would kill the freshly spawned process through the
    // PID file. This makes the lifecycle tolerant while AppController ordering
    // is being kept backward-compatible.
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
    _stopTrafficMonitor();
    _sub?.cancel();
    _logSub?.cancel();
    _core.dispose();
    upBpsNotifier.dispose();
    downBpsNotifier.dispose();
    super.dispose();
  }

  /// Graceful shutdown: kill core process + disable system proxy.
  /// Called from the window-close handler before [windowManager.destroy()].
  Future<void> shutdown() async {
    if (Platform.isAndroid) {
      await _androidCore.stop();
      return;
    }
    if (!Platform.isWindows) return;
    _stopTrafficMonitor();
    await _sub?.cancel();
    await _logSub?.cancel();
    _sub = null;
    _logSub = null;
    _core.dispose(); // synchronously kills the process + deletes PID file
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
  Future<void> startCoreOnly({
    required List<NodeModel> nodes,
    required NodeModel currentNode,
    required ProxyMode proxyMode,
    required String dnsMode,
    required int proxyPort,
  }) async {
    if (Platform.isAndroid) return;
    if (_core.isRunning) return;
    final validNodes = nodes.where((n) => n.rawUri.isNotEmpty).toList();
    if (validNodes.isEmpty) return;

    final config = SingboxConfig.buildFullConfig(
      validNodes,
      selectedTag: SingboxConfig.nodeTagFor(currentNode),
      port: proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: NetworkMode.system, // no TUN in background mode
    );
    if (config == null) return;

    try {
      final configPath = await SingboxConfig.writeConfig(config);
      await _core.start(configPath, apiPort: SingboxConfig.defaultApiPort);
      // _status stays disconnected — proxy is NOT enabled yet.
      if (_core.isRunning) notifyListeners();
    } catch (_) {
      // Background start failure is non-fatal; user can still connect manually.
    }
  }

  /// Rebuilds the sing-box config and restarts the core when it is already
  /// running. If the user was connected, it reconnects with the new config;
  /// otherwise it keeps the core alive in background mode for latency testing.
  Future<String?> reloadCore({
    required List<NodeModel> nodes,
    required NodeModel currentNode,
    required ProxyMode proxyMode,
    required String dnsMode,
    required int proxyPort,
    NetworkMode networkMode = NetworkMode.system,
  }) async {
    if (Platform.isAndroid) {
      if (coreConnecting || _status != ConnectionStatus.connected) return null;
      await _androidCore.stop();
      _connectedAt = null;
      _status = ConnectionStatus.disconnected;
      return _toggleAndroidConnection(
        nodes: nodes,
        currentNode: currentNode,
        proxyMode: proxyMode,
        dnsMode: dnsMode,
        proxyPort: proxyPort,
      );
    }

    if (coreConnecting) return null;

    final wasConnected = _status == ConnectionStatus.connected;
    final hadProcess = _core.isRunning;
    if (!hadProcess) {
      await startCoreOnly(
        nodes: nodes,
        currentNode: currentNode,
        proxyMode: proxyMode,
        dnsMode: dnsMode,
        proxyPort: proxyPort,
      );
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

    if (wasConnected) {
      return toggleConnection(
        nodes: nodes,
        currentNode: currentNode,
        proxyMode: proxyMode,
        dnsMode: dnsMode,
        proxyPort: proxyPort,
        networkMode: networkMode,
      );
    }

    await startCoreOnly(
      nodes: nodes,
      currentNode: currentNode,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      proxyPort: proxyPort,
    );
    return null;
  }

  /// Toggles proxy on/off. When the sing-box process is already running
  /// (started via [startCoreOnly]), connecting only enables the system proxy —
  /// no process restart needed. Disconnecting keeps the process alive so
  /// latency testing continues in the background.
  ///
  /// TUN mode always performs a full restart since the TUN adapter cannot be
  /// toggled without reloading the config.
  Future<String?> toggleConnection({
    required List<NodeModel> nodes,
    required NodeModel currentNode,
    required ProxyMode proxyMode,
    required String dnsMode,
    required int proxyPort,
    NetworkMode networkMode = NetworkMode.system,
  }) async {
    if (Platform.isAndroid) {
      return _toggleAndroidConnection(
        nodes: nodes,
        currentNode: currentNode,
        proxyMode: proxyMode,
        dnsMode: dnsMode,
        proxyPort: proxyPort,
      );
    }

    if (coreConnecting) return null;

    // ── DISCONNECT ──────────────────────────────────────────────────────────
    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.disconnecting;
      notifyListeners();
      _stopTrafficMonitor();
      await ProxySetter.disable();
      if (networkMode == NetworkMode.tun) {
        // TUN requires a full restart to remove the adapter; stop the process.
        await _core.stop();
      }
      // System proxy mode: keep process alive for background latency testing.
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return null;
    }

    // ── CONNECT ─────────────────────────────────────────────────────────────
    final validNodes = nodes.where((n) => n.rawUri.isNotEmpty).toList();
    if (validNodes.isEmpty) {
      _coreError = '没有可用节点，请刷新节点列表后重试';
      notifyListeners();
      return _coreError;
    }

    final selectedTag = SingboxConfig.nodeTagFor(currentNode);

    // Fast path: core already running in system proxy mode — just enable proxy.
    if (_core.isRunning && networkMode == NetworkMode.system) {
      _status = ConnectionStatus.connecting;
      _coreError = '';
      notifyListeners();
      try {
        await SingboxApiClient.switchProxy(
          selectedTag,
          apiPort: SingboxConfig.defaultApiPort,
        );
        await ProxySetter.enable(port: proxyPort);
        _connectedAt = DateTime.now();
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } catch (_) {
        _coreError = '连接失败，请重启客户端后重试';
        _status = ConnectionStatus.error;
      }
      notifyListeners();
      return _coreError.isNotEmpty ? _coreError : null;
    }

    // Full start: build config, (re)start process, enable proxy.
    final config = SingboxConfig.buildFullConfig(
      validNodes,
      selectedTag: selectedTag,
      port: proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: networkMode,
    );

    if (config == null) {
      _coreError = '生成配置失败，请选择其他节点后重试';
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      final configPath = await SingboxConfig.writeConfig(config);
      await _core.start(configPath, apiPort: SingboxConfig.defaultApiPort);

      if (_core.isRunning) {
        if (networkMode == NetworkMode.system) {
          await ProxySetter.enable(port: proxyPort);
        }
        _connectedAt = DateTime.now();
        _coreError = '';
        _status = ConnectionStatus.connected;
        _startTrafficMonitor();
      } else {
        _coreError = _core.lastError.isNotEmpty
            ? _core.lastError
            : '连接失败，请检查 sing-box.exe 是否存在';
        _status = ConnectionStatus.error;
      }
    } catch (e) {
      final raw = '$e';
      if (raw.contains('Access') || raw.contains('denied')) {
        _coreError = '权限不足，请以管理员身份运行客户端';
      } else {
        _coreError = '连接失败，请重启客户端后重试';
      }
      _status = ConnectionStatus.error;
    } finally {
      notifyListeners();
    }
    return _coreError.isNotEmpty ? _coreError : null;
  }

  Future<String?> _toggleAndroidConnection({
    required List<NodeModel> nodes,
    required NodeModel currentNode,
    required ProxyMode proxyMode,
    required String dnsMode,
    required int proxyPort,
  }) async {
    if (coreConnecting) return null;

    if (_status == ConnectionStatus.connected) {
      _status = ConnectionStatus.disconnecting;
      notifyListeners();
      await _androidCore.stop();
      _stopTrafficMonitor();
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      notifyListeners();
      return null;
    }

    final validNodes = nodes.where((n) => n.rawUri.isNotEmpty).toList();
    if (validNodes.isEmpty) {
      _coreError = '没有可用节点，请刷新节点列表后重试';
      notifyListeners();
      return _coreError;
    }

    final config = SingboxConfig.buildFullConfig(
      validNodes,
      selectedTag: SingboxConfig.nodeTagFor(currentNode),
      port: proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
      networkMode: NetworkMode.tun,
    );

    if (config == null) {
      _coreError = '生成配置失败，请选择其他节点后重试';
      notifyListeners();
      return _coreError;
    }

    _status = ConnectionStatus.connecting;
    _coreError = '';
    notifyListeners();

    try {
      final configJson = SingboxConfig.encodeConfig(config);
      final ok = await _androidCore.start(configJson);
      if (ok) {
        _connectedAt = DateTime.now();
        _status = ConnectionStatus.connected;
      } else {
        _coreError = _androidCore.lastError.isNotEmpty
            ? _androidCore.lastError
            : 'Android 核心启动失败';
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

  /// Stops the core and clears connection state. Called by [AppController.logout].
  void stopAndReset() {
    if (Platform.isAndroid) {
      unawaited(_androidCore.stop());
      _connectedAt = null;
      _coreError = '';
      _status = ConnectionStatus.disconnected;
      return;
    }
    if (_core.isRunning) {
      unawaited(_core.stop());
      unawaited(ProxySetter.disable());
      _connectedAt = null;
    }
    _coreError = '';
    _status = ConnectionStatus.disconnected;
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
    if (!_core.isRunning) return;
    await SingboxApiClient.setMode(
      proxyMode.clashValue,
      apiPort: SingboxConfig.defaultApiPort,
    );
  }

  // ── Proxy repair ──────────────────────────────────────────────────────────

  /// Force-sync the Windows system proxy to match the current core state.
  Future<void> fixProxy(int proxyPort) async {
    if (!Platform.isWindows) return;
    if (_core.isRunning) {
      await ProxySetter.enable(port: proxyPort);
    } else {
      await ProxySetter.disable();
    }
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  /// Run `sing-box version` and return the version string.
  static Future<String> getCoreVersion() async {
    if (Platform.isAndroid) {
      return AndroidCoreManager().version();
    }
    if (!Platform.isWindows) return '当前平台暂未接入核心';
    final exe = CoreManager.findExecutable();
    if (exe == null) return '未找到 sing-box.exe';
    try {
      final r = await Process.run(exe, ['version']).timeout(
        const Duration(seconds: 3),
        onTimeout: () => ProcessResult(0, 1, '', ''),
      );
      final out = '${r.stdout}'.trim();
      final m = RegExp(r'sing-box version ([\d.]+\S*)').firstMatch(out);
      return m?.group(1) ?? out.split('\n').first.trim();
    } catch (_) {
      return '获取失败';
    }
  }

  /// Write the buffered log lines to %LOCALAPPDATA%\Litchi\ and return the path.
  Future<String?> exportLogs() async {
    if (_logs.isEmpty) return null;
    try {
      final base = Platform.environment['LOCALAPPDATA'] ??
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
    _trafficSub = SingboxApiClient.trafficStream(
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
    if (nodes.isEmpty || !_core.isRunning) return;

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
      _stopTrafficMonitor();
      _connectedAt = null;
      if (state == CoreState.error && _core.lastError.isNotEmpty) {
        _coreError = _core.lastError;
      }
      _status = state == CoreState.error
          ? ConnectionStatus.error
          : ConnectionStatus.disconnected;
      unawaited(ProxySetter.disable());
      notifyListeners();
    }
  }
}

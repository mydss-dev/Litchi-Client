import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/services/core_manager.dart';
import '../shared/services/latency_tester.dart';
import '../shared/services/proxy_setter.dart';
import '../shared/services/singbox_api_client.dart';
import '../shared/services/singbox_config.dart';

/// Owns the sing-box process, connection lifecycle, and latency testing.
///
/// Settings values and the node list are passed in at call time to avoid
/// storing references that would create circular dependencies.
class CoreController extends ChangeNotifier {
  final CoreManager _core = CoreManager();
  StreamSubscription<CoreState>? _sub;
  StreamSubscription<String>? _logSub;

  DateTime? _connectedAt;
  bool _coreConnecting = false;
  String _coreError = '';

  // Rolling log buffer — last 500 lines, timestamped.
  final _logs = <String>[];
  static const _maxLogs = 500;

  bool get isRunning => _core.isRunning;
  bool get coreRunning => _core.isRunning;
  bool get coreConnecting => _coreConnecting;
  String get coreError => _coreError;
  Stream<String> get logStream => _core.logStream;
  List<String> get recentLogs => List.unmodifiable(_logs);
  Duration get connectedDuration => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  /// Must be called once after construction (inside [AppController.init]).
  void init() {
    _sub = _core.stateStream.listen(_onCoreStateChanged);
    _logSub = _core.logStream.listen((line) {
      final ts = DateTime.now().toLocal().toString().substring(11, 19);
      _logs.add('[$ts] $line');
      if (_logs.length > _maxLogs) _logs.removeAt(0);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _logSub?.cancel();
    _core.dispose();
    super.dispose();
  }

  /// Graceful shutdown: kill core process + disable system proxy.
  /// Called from the window-close handler before [windowManager.destroy()].
  Future<void> shutdown() async {
    await _sub?.cancel();
    await _logSub?.cancel();
    _sub = null;
    _logSub = null;
    _core.dispose(); // synchronously kills the process + deletes PID file
    try {
      await ProxySetter.disable();
    } catch (_) {}
  }

  // ── Connection ────────────────────────────────────────────────────────────

  /// Toggles sing-box on/off. Settings and node list are provided by the caller
  /// rather than stored here to avoid coupling with [AppController].
  Future<String?> toggleConnection({
    required List<NodeModel> nodes,
    required NodeModel currentNode,
    required String proxyMode,
    required String dnsMode,
    required int proxyPort,
  }) async {
    if (_coreConnecting) return null;

    if (_core.isRunning) {
      _coreConnecting = true;
      notifyListeners();
      await _core.stop();
      await ProxySetter.disable();
      _connectedAt = null;
      _coreError = '';
      _coreConnecting = false;
      notifyListeners();
      return null;
    }

    final validNodes = nodes.where((n) => n.rawUri.isNotEmpty).toList();
    if (validNodes.isEmpty) {
      _coreError = '没有可用节点，请刷新节点列表后重试';
      notifyListeners();
      return _coreError;
    }

    final selectedTag = SingboxConfig.nodeTagFor(currentNode);
    final config = SingboxConfig.buildFullConfig(
      validNodes,
      selectedTag: selectedTag,
      port: proxyPort,
      apiPort: SingboxConfig.defaultApiPort,
      proxyMode: proxyMode,
      dnsMode: dnsMode,
    );

    if (config == null) {
      _coreError = '生成配置失败，请选择其他节点后重试';
      notifyListeners();
      return _coreError;
    }

    _coreConnecting = true;
    _coreError = '';
    notifyListeners();

    try {
      final configPath = await SingboxConfig.writeConfig(config);
      await _core.start(configPath, apiPort: SingboxConfig.defaultApiPort);

      if (_core.isRunning) {
        await ProxySetter.enable(port: proxyPort);
        _connectedAt = DateTime.now();
        _coreError = '';
      } else {
        _coreError = _core.lastError.isNotEmpty
            ? _core.lastError
            : '连接失败，请检查 sing-box.exe 是否存在';
      }
    } catch (e) {
      final raw = '$e';
      if (raw.contains('Access') || raw.contains('denied')) {
        _coreError = '权限不足，请以管理员身份运行客户端';
      } else {
        _coreError = '连接失败，请重启客户端后重试';
      }
    } finally {
      _coreConnecting = false;
      notifyListeners();
    }
    return _coreError.isNotEmpty ? _coreError : null;
  }

  /// Stops the core and clears connection state. Called by [AppController.logout].
  void stopAndReset() {
    if (_core.isRunning) {
      _core.stop();
      ProxySetter.disable();
      _connectedAt = null;
    }
    _coreError = '';
    _coreConnecting = false;
  }

  // ── Node switching ────────────────────────────────────────────────────────

  /// Switches the active proxy at runtime without restarting the core.
  /// Returns true if the Clash API accepted the change.
  Future<bool> switchNode(NodeModel node) => SingboxApiClient.switchProxy(
        SingboxConfig.nodeTagFor(node),
        apiPort: SingboxConfig.defaultApiPort,
      );

  // ── Mode switching ────────────────────────────────────────────────────────

  /// Apply [proxyMode] to the running core via Clash API (no restart needed).
  Future<void> setMode(String proxyMode) async {
    if (!_core.isRunning) return;
    await SingboxApiClient.setMode(
      _toClashMode(proxyMode),
      apiPort: SingboxConfig.defaultApiPort,
    );
  }

  static String _toClashMode(String mode) => switch (mode) {
        '全局模式' => 'global',
        '直连模式' => 'direct',
        _ => 'rule',
      };

  // ── Proxy repair ──────────────────────────────────────────────────────────

  /// Force-sync the Windows system proxy to match the current core state.
  Future<void> fixProxy(int proxyPort) async {
    if (_core.isRunning) {
      await ProxySetter.enable(port: proxyPort);
    } else {
      await ProxySetter.disable();
    }
  }

  // ── Diagnostics ───────────────────────────────────────────────────────────

  /// Run `sing-box version` and return the version string.
  static Future<String> getCoreVersion() async {
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

  // ── Latency testing ───────────────────────────────────────────────────────

  /// Tests latency for every node in [nodes] (max 10 concurrent).
  ///
  /// Calls [onResult] with the index and updated node as each result arrives.
  /// When the core is running, uses the Clash API; otherwise falls back to
  /// direct TCP ping.
  Future<void> testLatencies(
    List<NodeModel> nodes, {
    required void Function(int idx, NodeModel updated) onResult,
  }) async {
    if (nodes.isEmpty) return;
    final sem = _Semaphore(10);
    await Future.wait(
      nodes.asMap().entries.map((e) async {
        await sem.acquire();
        try {
          final node = e.value;
          final int ms;
          if (_core.isRunning) {
            ms = await SingboxApiClient.testDelay(
                      SingboxConfig.nodeTagFor(node),
                      apiPort: SingboxConfig.defaultApiPort,
                    ) ??
                LatencyTester.unreachable;
          } else {
            ms = await LatencyTester.ping(node.server, node.port);
          }
          onResult(e.key, node.copyWith(latency: ms));
        } finally {
          sem.release();
        }
      }),
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  void _onCoreStateChanged(CoreState state) {
    // React only to unexpected crashes (deliberate stop() clears _connectedAt first).
    if ((state == CoreState.error || state == CoreState.stopped) &&
        (_connectedAt != null || _coreConnecting)) {
      _connectedAt = null;
      _coreConnecting = false;
      if (_core.lastError.isNotEmpty) _coreError = _core.lastError;
      ProxySetter.disable();
      notifyListeners();
    }
  }
}

// ── Simple counting semaphore ─────────────────────────────────────────────────

class _Semaphore {
  _Semaphore(this._max);

  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_count < _max) {
      _count++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
    _count++;
  }

  void release() {
    _count--;
    if (_queue.isNotEmpty) _queue.removeAt(0).complete();
  }
}

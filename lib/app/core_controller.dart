import 'dart:async';

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

  DateTime? _connectedAt;
  bool _coreConnecting = false;
  String _coreError = '';

  bool get isRunning => _core.isRunning;
  bool get coreRunning => _core.isRunning;
  bool get coreConnecting => _coreConnecting;
  String get coreError => _coreError;
  Stream<String> get logStream => _core.logStream;
  Duration get connectedDuration => _connectedAt != null
      ? DateTime.now().difference(_connectedAt!)
      : Duration.zero;

  /// Must be called once after construction (inside [AppController.init]).
  void init() {
    _sub = _core.stateStream.listen(_onCoreStateChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _core.dispose();
    super.dispose();
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
      _coreError = '连接异常: $e';
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
  Future<void> switchNode(NodeModel node) async {
    await SingboxApiClient.switchProxy(
      SingboxConfig.nodeTagFor(node),
      apiPort: SingboxConfig.defaultApiPort,
    );
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

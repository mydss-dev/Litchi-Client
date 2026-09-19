import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';

/// Owns node-list state and selection: available nodes, the current /
/// auto-selected node, and latency bookkeeping.
///
/// Extracted from [AppController]. Core coordination (starting the process,
/// switching outbounds, running the latency test) stays in AppController — this
/// controller is the node *data* authority it drives.
class NodeController extends ChangeNotifier {
  static const _empty = NodeModel(id: '', name: '', flag: '', latency: 0);

  List<NodeModel> _nodes = const [];
  NodeModel _currentNode = _empty;
  bool _autoSelected = false;

  List<NodeModel> get nodes => _nodes;
  bool get autoSelected => _autoSelected;
  bool get isEmpty => _nodes.isEmpty;
  bool get isNotEmpty => _nodes.isNotEmpty;
  int get length => _nodes.length;

  /// Always resolves the selection against the authoritative node list.
  ///
  /// Latency tests replace list entries with updated immutable models. Keeping
  /// the originally selected object here would leave dashboard widgets reading
  /// its stale latency while the picker already showed the new value.
  NodeModel get currentNode {
    if (_autoSelected) return _bestNode ?? _canonicalCurrentNode;
    return _canonicalCurrentNode;
  }

  NodeModel get _canonicalCurrentNode {
    for (final node in _nodes) {
      if (node.id == _currentNode.id) return node;
    }
    return _currentNode;
  }

  NodeModel? get _bestNode {
    NodeModel? best;
    for (final n in _nodes) {
      if (n.latency <= 0 || n.latency >= 9999) continue;
      if (best == null || n.latency < best.latency) best = n;
    }
    return best;
  }

  void setNodes(List<NodeModel> nodes) {
    // Preserve completed results for unchanged endpoints across metadata and
    // subscription refreshes, but never transfer latency to another server.
    final previous = <String, int>{
      for (final node in _nodes)
        if (!node.isAuto && node.latency > 0 && node.latency != -1)
          '${node.name}\u0000${node.server}\u0000${node.port}': node.latency,
    };
    _nodes = nodes
        .map((node) {
          if (node.isAuto || node.latency != 0) return node;
          final key = '${node.name}\u0000${node.server}\u0000${node.port}';
          final latency = previous[key];
          return latency == null ? node : node.copyWith(latency: latency);
        })
        .toList(growable: false);
    notifyListeners();
  }

  void markNodeLatency(String id, int latency) {
    _nodes = _nodes
        .map((node) => node.id == id ? node.copyWith(latency: latency) : node)
        .toList(growable: false);
    notifyListeners();
  }

  void selectNode(NodeModel node) {
    _autoSelected = false;
    _currentNode = node;
    notifyListeners();
  }

  void selectAuto() {
    _autoSelected = true;
    notifyListeners();
  }

  /// Restore the last manually-selected node by id; fall back to the first node
  /// in auto-select mode when the id is missing.
  void restoreLastSelection(String lastNodeId) {
    if (_nodes.isEmpty) return;
    final saved = lastNodeId.isNotEmpty
        ? _nodes.where((n) => n.id == lastNodeId).firstOrNull
        : null;
    if (saved != null) {
      _currentNode = saved;
      _autoSelected = false;
    } else {
      _currentNode = _nodes.first;
      _autoSelected = true;
    }
    notifyListeners();
  }

  // ── Latency bookkeeping ────────────────────────────────────────────────────

  /// Sets every node's latency to [latency] (-1 testing, 9999 failed, 0 reset).
  void markAllLatency(int latency) {
    _nodes = _nodes.map((n) => n.copyWith(latency: latency)).toList();
    notifyListeners();
  }

  /// Applies a batch of latencies keyed by node id (TCP-ping path).
  void applyLatencyById(Map<String, int> latencyById) {
    _nodes = _nodes
        .map(
          (n) => latencyById.containsKey(n.id)
              ? n.copyWith(latency: latencyById[n.id])
              : n,
        )
        .toList();
    notifyListeners();
  }

  /// Applies a single result by index during controller delay testing.
  void applyLatencyAt(int index, NodeModel updated) {
    if (index < 0 || index >= _nodes.length) return;
    final list = List<NodeModel>.from(_nodes);
    list[index] = updated;
    _nodes = list;
    notifyListeners();
  }

  void reset() {
    _nodes = const [];
    _currentNode = _empty;
    _autoSelected = false;
    notifyListeners();
  }
}

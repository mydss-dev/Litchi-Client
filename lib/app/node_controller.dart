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
    _nodes = nodes;
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

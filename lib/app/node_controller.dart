import 'package:flutter/foundation.dart';

import '../shared/models/app_models.dart';
import '../shared/models/node_runtime_state.dart';
import '../shared/services/node_selection_service.dart';

/// Owns node-list state and selection: the available nodes, the current /
/// auto-selected node, and latency-result bookkeeping.
///
/// Extracted from [AppController]. Core coordination (starting the process,
/// switching outbounds, running the latency test) stays in AppController — this
/// controller is the node *data* authority it drives.
class NodeController extends ChangeNotifier {
  NodeRuntimeState _state = const NodeRuntimeState();
  NodeRuntimeState get state => _state;

  List<NodeModel> get nodes => _state.nodes;
  NodeModel get currentNode => _state.displayNode;
  bool get autoSelected => _state.autoSelected;
  bool get isEmpty => _state.isEmpty;
  bool get isNotEmpty => !_state.isEmpty;

  void setNodes(List<NodeModel> nodes) {
    _state = _state.copyWith(nodes: nodes);
    notifyListeners();
  }

  /// Restores the last manually-selected node (falling back to auto-select).
  void restoreLastSelection(String lastNodeId) {
    final restored = NodeSelectionService.restoreLastSelection(
      nodes: _state.nodes,
      lastNodeId: lastNodeId,
    );
    _state = _state.copyWith(
      currentNode: restored.currentNode,
      autoSelected: restored.autoSelected,
    );
    notifyListeners();
  }

  void selectNode(NodeModel node) {
    _state = _state.copyWith(currentNode: node, autoSelected: false);
    notifyListeners();
  }

  void selectAuto() {
    _state = _state.copyWith(autoSelected: true);
    notifyListeners();
  }

  // ── Latency bookkeeping ────────────────────────────────────────────────────

  void clearLatency() {
    _state = _state.copyWith(
      nodes: NodeSelectionService.clearLatency(_state.nodes),
    );
    notifyListeners();
  }

  void markLatencyTesting() {
    _state = _state.copyWith(
      nodes: NodeSelectionService.markLatencyTesting(_state.nodes),
    );
    notifyListeners();
  }

  void markLatencyFailed() {
    _state = _state.copyWith(
      nodes: NodeSelectionService.markLatencyFailed(_state.nodes),
    );
    notifyListeners();
  }

  void applyLatencyResults(Map<int, NodeModel> pending) {
    _state = _state.copyWith(
      nodes: NodeSelectionService.applyLatencyResults(_state.nodes, pending),
    );
    notifyListeners();
  }

  void applyLatencyResult(NodeModel updated) {
    final index = _state.nodes.indexWhere((node) => node.id == updated.id);
    if (index < 0) return;
    final nodes = List<NodeModel>.from(_state.nodes);
    nodes[index] = updated;
    _state = _state.copyWith(nodes: nodes);
    notifyListeners();
  }

  void reset() {
    _state = const NodeRuntimeState();
    notifyListeners();
  }
}

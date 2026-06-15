import '../services/node_selection_service.dart';
import 'app_models.dart';

class NodeRuntimeState {
  const NodeRuntimeState({
    this.currentNode = NodeSelectionService.emptyNode,
    this.nodes = const [],
    this.autoSelected = false,
  });

  final NodeModel currentNode;
  final List<NodeModel> nodes;
  final bool autoSelected;

  NodeModel get displayNode =>
      autoSelected ? (bestLatencyNode ?? currentNode) : currentNode;

  NodeModel? get bestLatencyNode => NodeSelectionService.bestLatencyNode(nodes);

  bool get isEmpty => nodes.isEmpty;

  NodeRuntimeState copyWith({
    NodeModel? currentNode,
    List<NodeModel>? nodes,
    bool? autoSelected,
  }) {
    return NodeRuntimeState(
      currentNode: currentNode ?? this.currentNode,
      nodes: nodes ?? this.nodes,
      autoSelected: autoSelected ?? this.autoSelected,
    );
  }
}

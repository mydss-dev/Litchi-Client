import '../models/app_models.dart';

class NodeSelectionState {
  const NodeSelectionState({
    required this.currentNode,
    required this.autoSelected,
  });

  final NodeModel currentNode;
  final bool autoSelected;
}

abstract final class NodeSelectionService {
  static const emptyNode = NodeModel(id: '', name: '', flag: '', latency: 0);

  static NodeSelectionState restoreLastSelection({
    required List<NodeModel> nodes,
    required String lastNodeId,
  }) {
    if (nodes.isEmpty) {
      return const NodeSelectionState(
        currentNode: emptyNode,
        autoSelected: false,
      );
    }

    final saved = lastNodeId.isNotEmpty
        ? nodes.where((node) => node.id == lastNodeId).firstOrNull
        : null;
    if (saved != null) {
      return NodeSelectionState(currentNode: saved, autoSelected: false);
    }

    return NodeSelectionState(currentNode: nodes.first, autoSelected: true);
  }

  static NodeModel? bestLatencyNode(List<NodeModel> nodes) {
    NodeModel? best;
    for (final node in nodes) {
      if (node.latency <= 0 || node.latency >= 9999) continue;
      if (best == null || node.latency < best.latency) best = node;
    }
    return best;
  }

  static List<NodeModel> markLatencyTesting(List<NodeModel> nodes) {
    return nodes.map((node) => node.copyWith(latency: -1)).toList();
  }

  static List<NodeModel> markLatencyFailed(List<NodeModel> nodes) {
    return nodes.map((node) => node.copyWith(latency: 9999)).toList();
  }

  static List<NodeModel> clearLatency(List<NodeModel> nodes) {
    return nodes.map((node) => node.copyWith(latency: 0)).toList();
  }

  static List<NodeModel> applyLatencyResults(
    List<NodeModel> nodes,
    Map<int, NodeModel> results,
  ) {
    if (results.isEmpty) return nodes;
    final list = List<NodeModel>.from(nodes);
    for (final entry in results.entries) {
      if (entry.key < 0 || entry.key >= list.length) continue;
      list[entry.key] = entry.value;
    }
    return list;
  }
}

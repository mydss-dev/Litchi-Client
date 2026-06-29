import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_selection_service.dart';

void main() {
  const nodes = [
    NodeModel(id: 'a', name: 'A', flag: '', latency: 80),
    NodeModel(id: 'b', name: 'B', flag: '', latency: 30),
    NodeModel(id: 'c', name: 'C', flag: '', latency: 9999),
  ];

  test('restores manually selected node when it still exists', () {
    final state = NodeSelectionService.restoreLastSelection(
      nodes: nodes,
      lastNodeId: 'b',
    );

    expect(state.currentNode.id, 'b');
    expect(state.autoSelected, isFalse);
  });

  test('falls back to auto select when last node is missing', () {
    final state = NodeSelectionService.restoreLastSelection(
      nodes: nodes,
      lastNodeId: 'missing',
    );

    expect(state.currentNode.id, 'a');
    expect(state.autoSelected, isTrue);
  });

  test('finds the best valid latency node', () {
    expect(NodeSelectionService.bestLatencyNode(nodes)?.id, 'b');
  });

  test('applies latency results by index safely', () {
    final updated = NodeSelectionService.applyLatencyResults(nodes, {
      0: nodes[0].copyWith(latency: 45),
      99: nodes[0].copyWith(latency: 1),
    });

    expect(updated[0].latency, 45);
    expect(updated[1].latency, 30);
    expect(updated, isNot(same(nodes)));
  });

  test('marks latency states in bulk', () {
    expect(
      NodeSelectionService.markLatencyTesting(
        nodes,
      ).map((node) => node.latency),
      everyElement(-1),
    );
    expect(
      NodeSelectionService.clearLatency(nodes).map((node) => node.latency),
      everyElement(0),
    );
  });
}

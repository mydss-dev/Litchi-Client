import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/node_runtime_state.dart';
import 'package:litchi_client/shared/services/node_selection_service.dart';

void main() {
  NodeModel node(String id, int latency) =>
      NodeModel(id: id, name: id, flag: '🌐', latency: latency);

  test('defaults to empty node runtime state', () {
    const state = NodeRuntimeState();

    expect(state.nodes, isEmpty);
    expect(state.currentNode, NodeSelectionService.emptyNode);
    expect(state.displayNode, NodeSelectionService.emptyNode);
    expect(state.autoSelected, isFalse);
    expect(state.isEmpty, isTrue);
  });

  test('display node uses best latency node when auto selected', () {
    final slow = node('slow', 300);
    final fast = node('fast', 50);
    final state = NodeRuntimeState(
      currentNode: slow,
      nodes: [slow, fast],
      autoSelected: true,
    );

    expect(state.bestLatencyNode, fast);
    expect(state.displayNode, fast);
  });

  test('display node keeps manual selection when auto select is disabled', () {
    final manual = node('manual', 300);
    final fast = node('fast', 50);
    final state = NodeRuntimeState(currentNode: manual, nodes: [manual, fast]);

    expect(state.displayNode, manual);
  });

  test('copyWith preserves omitted fields', () {
    final current = node('current', 100);
    final state = NodeRuntimeState(currentNode: current, autoSelected: true);

    final updated = state.copyWith(nodes: [current]);

    expect(updated.currentNode, current);
    expect(updated.nodes, [current]);
    expect(updated.autoSelected, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/node_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_selection_service.dart';

NodeModel _node(String id, {int latency = 0}) =>
    NodeModel(id: id, name: id, flag: '🏳', latency: latency);

void main() {
  test('setNodes then manual selection updates currentNode', () {
    final c = NodeController();
    c.setNodes([_node('a'), _node('b')]);
    expect(c.nodes, hasLength(2));

    c.selectNode(_node('b'));
    expect(c.autoSelected, isFalse);
    expect(c.currentNode.id, 'b');
  });

  test('restoreLastSelection falls back to auto when id is missing', () {
    final c = NodeController();
    c.setNodes([_node('a'), _node('b')]);
    c.restoreLastSelection('missing');
    expect(c.autoSelected, isTrue);
  });

  test('markLatencyTesting flags all nodes as in-progress', () {
    final c = NodeController();
    c.setNodes([_node('a', latency: 80), _node('b', latency: 120)]);
    c.markLatencyTesting();
    expect(c.nodes.every((n) => n.latency == -1), isTrue);
  });

  test('applyLatencyResults updates nodes by index', () {
    final c = NodeController();
    c.setNodes([_node('a'), _node('b')]);
    c.applyLatencyResults({0: _node('a', latency: 42)});
    expect(c.nodes[0].latency, 42);
  });

  test('reset clears nodes back to empty defaults', () {
    final c = NodeController();
    c.setNodes([_node('a')]);
    c.reset();
    expect(c.isEmpty, isTrue);
    expect(c.currentNode, NodeSelectionService.emptyNode);
  });
}

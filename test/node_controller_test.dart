import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/node_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';

void main() {
  NodeModel node(String id, int latency) =>
      NodeModel(id: id, name: id, flag: '🌐', latency: latency);

  test('manual selection follows batch latency updates from the node list', () {
    final controller = NodeController();
    final selected = node('selected', 0);
    controller.setNodes([selected, node('other', 0)]);
    controller.selectNode(selected);

    controller.applyLatencyById({'selected': 48, 'other': 90});

    expect(controller.currentNode.id, 'selected');
    expect(controller.currentNode.latency, 48);
  });

  test('manual selection follows streaming latency updates by index', () {
    final controller = NodeController();
    final selected = node('selected', 0);
    controller.setNodes([selected]);
    controller.selectNode(selected);

    controller.applyLatencyAt(0, selected.copyWith(latency: 36));

    expect(controller.currentNode.latency, 36);
  });

  test('manual selection follows bulk latency state changes', () {
    final controller = NodeController();
    final selected = node('selected', 52);
    controller.setNodes([selected]);
    controller.selectNode(selected);

    controller.markAllLatency(-1);
    expect(controller.currentNode.latency, -1);

    controller.markAllLatency(0);
    expect(controller.currentNode.latency, 0);
  });
}

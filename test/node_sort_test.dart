import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_sort.dart';

void main() {
  const nodes = [
    NodeModel(id: 'b', name: 'Beta', flag: '', latency: 120, code: 'US'),
    NodeModel(id: 'a', name: 'Alpha', flag: '', latency: 40, code: 'JP'),
    NodeModel(id: 'c', name: 'Charlie', flag: '', latency: 9999, code: 'DE'),
  ];

  test('keeps source order by default', () {
    expect(
      NodeSort.apply(nodes, NodeSortMode.original).map((node) => node.id),
      ['b', 'a', 'c'],
    );
  });

  test('sorts valid latency first and failed nodes last', () {
    expect(NodeSort.apply(nodes, NodeSortMode.latency).map((node) => node.id), [
      'a',
      'b',
      'c',
    ]);
  });

  test('sorts by name and region without mutating source', () {
    expect(NodeSort.apply(nodes, NodeSortMode.name).map((node) => node.id), [
      'a',
      'b',
      'c',
    ]);
    expect(NodeSort.apply(nodes, NodeSortMode.region).map((node) => node.id), [
      'c',
      'a',
      'b',
    ]);
    expect(nodes.map((node) => node.id), ['b', 'a', 'c']);
  });
}

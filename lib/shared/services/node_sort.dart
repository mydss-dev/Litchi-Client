import '../models/app_models.dart';

enum NodeSortMode {
  original('original'),
  latency('latency'),
  name('name'),
  region('region');

  const NodeSortMode(this.storageKey);
  final String storageKey;

  static NodeSortMode fromStorageKey(String? value) => values.firstWhere(
    (mode) => mode.storageKey == value,
    orElse: () => original,
  );
}

abstract final class NodeSort {
  static List<NodeModel> apply(Iterable<NodeModel> nodes, NodeSortMode mode) {
    final indexed = nodes.toList().asMap().entries.toList();
    if (mode == NodeSortMode.original) {
      return [for (final entry in indexed) entry.value];
    }

    int compare(MapEntry<int, NodeModel> a, MapEntry<int, NodeModel> b) {
      final result = switch (mode) {
        NodeSortMode.latency => _latencyRank(
          a.value,
        ).compareTo(_latencyRank(b.value)),
        NodeSortMode.name => _displayName(
          a.value,
        ).compareTo(_displayName(b.value)),
        NodeSortMode.region => _region(a.value).compareTo(_region(b.value)),
        NodeSortMode.original => 0,
      };
      return result != 0 ? result : a.key.compareTo(b.key);
    }

    indexed.sort(compare);
    return [for (final entry in indexed) entry.value];
  }

  static int _latencyRank(NodeModel node) {
    final latency = node.latency;
    return latency > 0 && latency < 9999 ? latency : 100000 + latency.abs();
  }

  static String _displayName(NodeModel node) =>
      (node.englishName.isNotEmpty ? node.englishName : node.name)
          .toLowerCase();

  static String _region(NodeModel node) =>
      '${node.code.toLowerCase()}:${_displayName(node)}';
}

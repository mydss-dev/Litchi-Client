import '../models/app_models.dart';

enum NodeFilterTab { all, favorite, premium, asia, europe, america, oceania }

abstract final class NodeFilter {
  static List<NodeModel> apply({
    required List<NodeModel> nodes,
    required String query,
    required NodeFilterTab tab,
    Set<String> favorites = const {},
  }) {
    final key = query.trim().toLowerCase();
    final filtered = <NodeModel>[];

    for (final node in nodes) {
      if (key.isNotEmpty && !_matchesQuery(node, key)) continue;
      if (!_matchesTab(node, tab, favorites)) continue;
      filtered.add(node);
    }

    return filtered;
  }

  static bool _matchesQuery(NodeModel node, String key) {
    return node.name.toLowerCase().contains(key) ||
        node.englishName.toLowerCase().contains(key) ||
        node.code.toLowerCase().contains(key) ||
        node.server.toLowerCase().contains(key);
  }

  static bool _matchesTab(
    NodeModel node,
    NodeFilterTab tab,
    Set<String> favorites,
  ) {
    return switch (tab) {
      NodeFilterTab.all => true,
      NodeFilterTab.favorite => favorites.contains(node.id),
      NodeFilterTab.premium => node.tags.contains('Premium'),
      NodeFilterTab.asia => node.region == NodeRegion.asia,
      NodeFilterTab.europe => node.region == NodeRegion.europe,
      NodeFilterTab.america => node.region == NodeRegion.america,
      NodeFilterTab.oceania => node.region == NodeRegion.oceania,
    };
  }
}

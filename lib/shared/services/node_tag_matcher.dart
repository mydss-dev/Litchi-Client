import '../models/app_models.dart';

/// Joins display-only tags from /user/server/fetch to connectable subscription
/// nodes. A subscription-generated sequential ID is NEVER the backend ID.
abstract final class NodeTagMatcher {
  static List<NodeModel> apply({
    required List<NodeModel> nodes,
    required List<Map<String, dynamic>> metadata,
  }) {
    final byName = <String, List<Map<String, dynamic>>>{};
    for (final record in metadata) {
      final name = '${record['name'] ?? ''}'.trim();
      if (name.isNotEmpty) {
        byName.putIfAbsent(name, () => []).add(record);
      }
    }
    final nameCounts = <String, int>{};
    for (final node in nodes) {
      if (node.isAuto) continue;
      final name = node.name.trim();
      nameCounts[name] = (nameCounts[name] ?? 0) + 1;
    }
    return nodes
        .map((node) {
          if (node.isAuto) return node;
          final name = node.name.trim();
          final candidates = byName[name] ?? const <Map<String, dynamic>>[];
          if (candidates.isEmpty) return node.copyWith(tags: const []);
          // Name alone is sufficient only when unique on BOTH sides. Repeated
          // names require an exact host + port match; never guess by list order.
          final matches = candidates.length == 1 && nameCounts[name] == 1
              ? candidates
              : candidates
                    .where((record) => _sameEndpoint(record, node))
                    .toList();
          return node.copyWith(
            tags: matches.length == 1
                ? _parseTags(matches.single['tags'])
                : const [],
          );
        })
        .toList(growable: false);
  }

  static bool _sameEndpoint(Map<String, dynamic> record, NodeModel node) {
    final host = '${record['host'] ?? ''}'.trim().toLowerCase();
    if (host.isEmpty || node.server.trim().isEmpty || node.port <= 0) {
      return false;
    }
    final portRaw = record['port'] ?? record['server_port'];
    final port = portRaw is num ? portRaw.toInt() : int.tryParse('$portRaw');
    return host == node.server.trim().toLowerCase() && port == node.port;
  }

  static List<String> _parseTags(Object? value) {
    if (value is! List) return const [];
    final tags = <String>[];
    for (final item in value) {
      if (item is! String) continue;
      final tag = item.trim();
      if (tag.isEmpty || tags.contains(tag)) continue;
      tags.add(tag);
      if (tags.length >= 8) break;
    }
    return List.unmodifiable(tags);
  }
}

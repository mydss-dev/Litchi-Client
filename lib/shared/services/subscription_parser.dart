import 'dart:convert';

import '../models/api_models.dart';

/// Parses a native sing-box subscription profile returned by V2Board.
///
/// Only connectable proxy outbounds are imported. The client deliberately
/// owns inbounds, DNS, routing, selectors and the Clash-compatible controller.
abstract final class SubscriptionParser {
  static const int maxBodyBytes = 4 * 1024 * 1024;
  static const int maxNodes = 5000;

  static List<RemoteNode> parse(String body) => parseProfile(body).nodes;

  static ParsedSubscriptionProfile parseProfile(String body) {
    if (utf8.encode(body).length > maxBodyBytes) {
      return const ParsedSubscriptionProfile(nodes: []);
    }
    try {
      final document = jsonDecode(body.trim());
      if (document is! Map || document['outbounds'] is! List) {
        return const ParsedSubscriptionProfile(nodes: []);
      }
      final nodes = <RemoteNode>[];
      var id = 1;
      for (final value in document['outbounds'] as List) {
        if (nodes.length >= maxNodes) break;
        if (value is! Map) continue;
        final outbound = Map<String, dynamic>.from(value);
        final type = '${outbound['type'] ?? ''}'.toLowerCase();
        if (!_proxyTypes.contains(type)) continue;
        final tag = '${outbound['tag'] ?? ''}'.trim();
        final server = '${outbound['server'] ?? ''}'.trim();
        final port = _outboundPort(outbound);
        final ranges = outbound['server_ports'];
        final hasPortRange = ranges is List && ranges.isNotEmpty;
        if (tag.isEmpty || server.isEmpty || (port <= 0 && !hasPortRange)) {
          continue;
        }
        outbound['_litchi_format'] = 'sing-box';
        nodes.add(
          RemoteNode(
            id: id++,
            name: tag,
            rate: 1,
            server: server,
            port: port,
            rawOutbound: outbound,
          ),
        );
      }
      return ParsedSubscriptionProfile(nodes: nodes);
    } on FormatException {
      return const ParsedSubscriptionProfile(nodes: []);
    }
  }

  static const _proxyTypes = {
    'vmess',
    'vless',
    'trojan',
    'shadowsocks',
    'hysteria',
    'hysteria2',
    'tuic',
    'anytls',
    'socks',
    'http',
    'wireguard',
    'ssh',
  };

  static int _outboundPort(Map<String, dynamic> outbound) {
    final direct = _asInt(outbound['server_port']);
    if (direct > 0) return direct;
    final ranges = outbound['server_ports'];
    if (ranges is! List || ranges.isEmpty) return 0;
    return int.tryParse('${ranges.first}'.split(':').first) ?? 0;
  }

  static int _asInt(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

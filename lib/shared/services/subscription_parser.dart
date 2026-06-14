import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/api_models.dart';

/// Parses subscription body text into a list of [RemoteNode].
///
/// Supports Base64-encoded URI lists, plain URI lists, and Clash YAML.
/// All methods are stateless and synchronous — no network access.
abstract final class SubscriptionParser {
  static const int maxBodyBytes = 4 * 1024 * 1024;
  static const int maxNodes = 5000;

  static List<RemoteNode> parse(String body) {
    if (utf8.encode(body).length > maxBodyBytes) return [];
    if (body.contains('\nproxies:') || body.startsWith('proxies:')) {
      return _parseClashYaml(body);
    }
    try {
      final decoded = utf8.decode(base64.decode(_pad(body)));
      if (decoded.contains('\nproxies:') || decoded.startsWith('proxies:')) {
        return _parseClashYaml(decoded);
      }
      if (decoded.contains('://')) return _parseUriList(decoded);
    } catch (_) {}
    if (body.contains('://')) return _parseUriList(body);
    return [];
  }

  // ── Clash YAML ────────────────────────────────────────────────────────────

  static List<RemoteNode> _parseClashYaml(String content) {
    final nodes = <RemoteNode>[];
    int id = 1;
    try {
      final doc = loadYaml(content);
      if (doc is! YamlMap) return nodes;
      final proxies = doc['proxies'];
      if (proxies is! YamlList) return nodes;
      for (final proxy in proxies) {
        if (nodes.length >= maxNodes) break;
        if (proxy is! YamlMap) continue;
        final rawOutbound = <String, dynamic>{};
        for (final entry in proxy.entries) {
          rawOutbound[entry.key.toString()] = _plainYamlValue(entry.value);
        }
        final name   = proxy['name']?.toString() ?? 'Node $id';
        final server = proxy['server']?.toString() ?? '';
        final port   = int.tryParse(proxy['port']?.toString() ?? '') ?? 0;
        final rate   = double.tryParse(proxy['rate']?.toString() ?? '') ?? 1.0;
        if (name.isNotEmpty) {
          nodes.add(RemoteNode(
            id: id++,
            name: name,
            server: server,
            port: port,
            rate: rate,
            rawOutbound: rawOutbound,
          ));
        }
      }
    } catch (_) {}
    return nodes;
  }

  // ── URI list ──────────────────────────────────────────────────────────────

  static List<RemoteNode> _parseUriList(String text) {
    final nodes = <RemoteNode>[];
    int id = 1;
    for (final raw in text.split('\n')) {
      if (nodes.length >= maxNodes) break;
      final line = raw.trim();
      if (line.isEmpty) continue;
      final node = _parseUri(line, id);
      if (node != null) { nodes.add(node); id++; }
    }
    return nodes;
  }

  static RemoteNode? _parseUri(String uri, int id) {
    try {
      if (uri.startsWith('vmess://'))    return _parseVmess(uri, id);
      if (uri.startsWith('vless://'))    return _parseHostFrag(uri, id);
      if (uri.startsWith('trojan://'))   return _parseHostFrag(uri, id);
      if (uri.startsWith('hysteria2://') || uri.startsWith('hy2://')) {
        return _parseHostFrag(uri, id);
      }
      if (uri.startsWith('hysteria://')) return _parseHostFrag(uri, id);
      if (uri.startsWith('ss://'))       return _parseSS(uri, id);
    } catch (_) {}
    return null;
  }

  static RemoteNode _parseVmess(String uri, int id) {
    final b64 = uri.substring('vmess://'.length);
    final j = jsonDecode(utf8.decode(base64.decode(_pad(b64))))
        as Map<String, dynamic>;
    return RemoteNode(
      id: id,
      name:   _decodeStr(j['ps']?.toString()) ?? 'VMess $id',
      server: j['add']?.toString() ?? '',
      port:   int.tryParse(j['port']?.toString() ?? '') ?? 0,
      rate:   double.tryParse(j['rate']?.toString() ?? '') ?? 1.0,
      rawUri: uri,
    );
  }

  static RemoteNode _parseHostFrag(String uri, int id) {
    final hashIdx = uri.lastIndexOf('#');
    final name = hashIdx >= 0
        ? (_decodeStr(uri.substring(hashIdx + 1)) ?? 'Node $id')
        : 'Node $id';
    final body = uri.substring(uri.indexOf('://') + 3,
        hashIdx > 0 ? hashIdx : uri.length);
    final authority = body.split('?').first;
    final atIdx = authority.lastIndexOf('@');
    final hostPort = atIdx >= 0 ? authority.substring(atIdx + 1) : authority;
    final colonIdx = hostPort.lastIndexOf(':');
    final server = colonIdx >= 0 ? hostPort.substring(0, colonIdx) : hostPort;
    final port   = colonIdx >= 0 ? (int.tryParse(hostPort.substring(colonIdx + 1)) ?? 0) : 0;
    return RemoteNode(id: id, name: name, server: server, port: port, rate: 1.0, rawUri: uri);
  }

  static RemoteNode _parseSS(String uri, int id) {
    final hashIdx = uri.lastIndexOf('#');
    final name = hashIdx >= 0
        ? (_decodeStr(uri.substring(hashIdx + 1)) ?? 'SS $id')
        : 'SS $id';
    String server = ''; int port = 0;
    try {
      final body = uri.substring('ss://'.length, hashIdx > 0 ? hashIdx : uri.length);
      final atIdx = body.lastIndexOf('@');
      if (atIdx >= 0) {
        final hp = body.substring(atIdx + 1);
        final c  = hp.lastIndexOf(':');
        if (c >= 0) { server = hp.substring(0, c); port = int.tryParse(hp.substring(c + 1)) ?? 0; }
      } else {
        final decoded = utf8.decode(base64.decode(_pad(body)));
        final a = decoded.lastIndexOf('@');
        if (a >= 0) {
          final hp = decoded.substring(a + 1);
          final c  = hp.lastIndexOf(':');
          if (c >= 0) { server = hp.substring(0, c); port = int.tryParse(hp.substring(c + 1)) ?? 0; }
        }
      }
    } catch (_) {}
    return RemoteNode(id: id, name: name, server: server, port: port, rate: 1.0, rawUri: uri);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _decodeStr(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return Uri.decodeComponent(s); } catch (_) { return s; }
  }

  static Object? _plainYamlValue(Object? value) {
    if (value is YamlMap) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _plainYamlValue(entry.value),
      };
    }
    if (value is YamlList) {
      return value.map(_plainYamlValue).toList();
    }
    return value;
  }

  static String _pad(String s) {
    final rem = s.length % 4;
    if (rem == 0) return s;
    return s + ('=' * (4 - rem));
  }
}

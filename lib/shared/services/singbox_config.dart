import 'dart:convert';
import 'dart:io';

import '../models/app_models.dart';

/// Generates sing-box JSON configs from parsed node lists.
///
/// Architecture:
/// - All nodes are written as outbounds with unique tags.
/// - A `selector` outbound named `PROXY` acts as the active exit.
/// - Clash-compatible REST API is enabled so the active node can be
///   switched at runtime via HTTP — no process restart required.
abstract final class SingboxConfig {
  static const int defaultPort   = 7890;
  static const int defaultApiPort = 9090;

  /// Build a complete multi-node config.
  ///
  /// [nodes]       — all available nodes (skips any with empty rawUri).
  /// [selectedTag] — the node tag that should be active on first start.
  /// [port]        — mixed inbound port (HTTP + SOCKS5).
  /// [apiPort]     — Clash-compatible REST API port for runtime switching.
  /// [proxyMode]   — '智能模式' | '全局模式' | '直连模式'
  /// [dnsMode]     — '系统 DNS' | 'Cloudflare' | 'Google'
  ///
  /// Returns null only when [nodes] is empty or all URIs are unparseable.
  static Map<String, dynamic>? buildFullConfig(
    List<NodeModel> nodes, {
    required String selectedTag,
    int port    = defaultPort,
    int apiPort = defaultApiPort,
    String proxyMode = '智能模式',
    String dnsMode   = '系统 DNS',
  }) {
    final outbounds = <Map<String, dynamic>>[];
    final tags      = <String>[];

    for (final n in nodes) {
      if (n.rawUri.isEmpty) continue;
      final ob = _parseOutbound(n.rawUri, tag: _nodeTag(n));
      if (ob == null) continue;
      outbounds.add(ob);
      tags.add(_nodeTag(n));
    }

    if (tags.isEmpty) return null;

    // Validate selected tag — fall back to first available.
    final activeTag = tags.contains(selectedTag) ? selectedTag : tags.first;

    final String routeFinal;
    final List<Map<String, dynamic>> routeRules;

    switch (proxyMode) {
      case '全局模式':
        routeFinal = 'PROXY';
        routeRules = [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ];
      case '直连模式':
        routeFinal = 'direct';
        routeRules = [
          {'protocol': 'dns', 'outbound': 'dns-out'},
        ];
      default: // 智能模式
        routeFinal = 'PROXY';
        routeRules = [
          {'protocol': 'dns', 'outbound': 'dns-out'},
          {'ip_is_private': true, 'outbound': 'direct'},
          {'geoip': 'cn', 'outbound': 'direct'},
          {'geosite': 'cn', 'outbound': 'direct'},
        ];
    }

    // Remote DNS address and routing depend on user's DNS mode setting.
    final String remoteDnsAddr;
    final String remoteDnsDetour;
    switch (dnsMode) {
      case 'Cloudflare':
        remoteDnsAddr   = 'tls://1.1.1.1';
        remoteDnsDetour = 'PROXY';
      case 'Google':
        remoteDnsAddr   = 'tls://8.8.8.8';
        remoteDnsDetour = 'PROXY';
      default: // '系统 DNS' — use OS resolver; no encryption, no tunnel
        remoteDnsAddr   = 'local';
        remoteDnsDetour = 'direct';
    }

    return {
      'log': {'level': 'warn', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          'secret': '',
        },
      },
      'dns': {
        'servers': [
          {
            'tag': 'remote-dns',
            'address': remoteDnsAddr,
            'detour': remoteDnsDetour,
          },
          {
            'tag': 'local-dns',
            'address': '223.5.5.5',
            'detour': 'direct',
          },
        ],
        'rules': [
          {'outbound': 'any', 'server': 'local-dns'},
          {'geosite': 'cn', 'server': 'local-dns'},
        ],
        'final': 'remote-dns',
        'independent_cache': true,
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': port,
        },
      ],
      'outbounds': [
        // Selector — the single exit point; switched at runtime via API.
        {
          'type': 'selector',
          'tag': 'PROXY',
          'outbounds': tags,
          'default': activeTag,
        },
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block',  'tag': 'block'},
        {'type': 'dns',    'tag': 'dns-out'},
      ],
      'route': {
        'rules': routeRules,
        'final': routeFinal,
        'auto_detect_interface': true,
      },
    };
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────

  /// Derive a stable sing-box outbound tag from a node.
  /// Tags must be non-empty and are used as REST API keys.
  static String nodeTagFor(NodeModel node) => _nodeTag(node);

  static String _nodeTag(NodeModel n) => 'node-${n.id}';

  // ── URI parsers ───────────────────────────────────────────────────────────

  static Map<String, dynamic>? _parseOutbound(String uri, {required String tag}) {
    try {
      if (uri.startsWith('vmess://'))   return _vmess(uri, tag: tag);
      if (uri.startsWith('vless://'))   return _vless(uri, tag: tag);
      if (uri.startsWith('trojan://'))  return _trojan(uri, tag: tag);
      if (uri.startsWith('ss://'))      return _ss(uri, tag: tag);
      if (uri.startsWith('hysteria2://') || uri.startsWith('hy2://')) {
        return _hysteria2(uri, tag: tag);
      }
    } catch (_) {}
    return null;
  }

  // ── VMess ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _vmess(String uri, {required String tag}) {
    final b64 = uri.substring('vmess://'.length);
    final j   = jsonDecode(utf8.decode(base64.decode(_pad(b64)))) as Map<String, dynamic>;

    final server = j['add']?.toString() ?? '';
    final port   = int.tryParse(j['port']?.toString() ?? '') ?? 0;
    final uuid   = j['id']?.toString() ?? '';
    final aid    = int.tryParse(j['aid']?.toString() ?? '') ?? 0;
    final scy    = j['scy']?.toString() ?? 'auto';
    final net    = j['net']?.toString() ?? 'tcp';
    final tls    = j['tls']?.toString() ?? '';
    final path   = j['path']?.toString() ?? '';
    final host   = j['host']?.toString() ?? '';

    final out = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': server,
      'server_port': port,
      'uuid': uuid,
      'security': scy.isEmpty ? 'auto' : scy,
      'alter_id': aid,
    };

    if (net == 'ws') {
      out['transport'] = {
        'type': 'ws',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty) 'headers': {'Host': host},
      };
    } else if (net == 'grpc') {
      out['transport'] = {
        'type': 'grpc',
        if (path.isNotEmpty) 'service_name': path,
      };
    } else if (net == 'h2') {
      out['transport'] = {
        'type': 'http',
        if (path.isNotEmpty) 'path': path,
        if (host.isNotEmpty) 'host': [host],
      };
    }

    if (tls == 'tls') {
      out['tls'] = {
        'enabled': true,
        if (host.isNotEmpty) 'server_name': host,
      };
    }

    return out;
  }

  // ── VLESS ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _vless(String uri, {required String tag}) {
    final (password, server, port, params) =
        _parseUserAtHostPort(uri, 'vless://');

    final security = params['security'] ?? '';
    final flow     = params['flow'] ?? '';
    final sni      = params['sni'] ?? params['servername'] ?? server;
    final type     = params['type'] ?? 'tcp';
    final path     = params['path'] ?? '';
    final host     = params['host'] ?? '';
    final pbk      = params['pbk'] ?? '';
    final sid      = params['sid'] ?? '';
    final fp       = params['fp'] ?? 'chrome';

    final out = <String, dynamic>{
      'type': 'vless',
      'tag': tag,
      'server': server,
      'server_port': port,
      'uuid': password,
      if (flow.isNotEmpty) 'flow': flow,
    };

    _applyTransport(out, type, path, host);

    if (security == 'tls') {
      out['tls'] = {
        'enabled': true,
        'server_name': sni,
        'utls': {'enabled': true, 'fingerprint': fp},
      };
    } else if (security == 'reality') {
      out['tls'] = {
        'enabled': true,
        'server_name': sni,
        'reality': {'enabled': true, 'public_key': pbk, 'short_id': sid},
        'utls': {'enabled': true, 'fingerprint': fp},
      };
    }

    return out;
  }

  // ── Trojan ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _trojan(String uri, {required String tag}) {
    final (password, server, port, params) =
        _parseUserAtHostPort(uri, 'trojan://');

    final sni      = params['sni'] ?? params['peer'] ?? server;
    final security = params['security'] ?? 'tls';
    final type     = params['type'] ?? 'tcp';
    final path     = params['path'] ?? '';
    final host     = params['host'] ?? '';
    final fp       = params['fp'] ?? '';

    final out = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': server,
      'server_port': port,
      'password': password,
    };

    _applyTransport(out, type, path, host);

    if (security != 'none') {
      out['tls'] = {
        'enabled': true,
        'server_name': sni,
        if (fp.isNotEmpty) 'utls': {'enabled': true, 'fingerprint': fp},
      };
    }

    return out;
  }

  // ── Shadowsocks ───────────────────────────────────────────────────────────

  static Map<String, dynamic> _ss(String uri, {required String tag}) {
    final hashIdx = uri.lastIndexOf('#');
    final main    = uri.substring('ss://'.length,
        hashIdx > 0 ? hashIdx : uri.length);

    String method = 'aes-128-gcm', password = '', server = '';
    int port = 0;

    final atIdx = main.lastIndexOf('@');
    if (atIdx >= 0) {
      final userInfo = main.substring(0, atIdx);
      final hostPort = main.substring(atIdx + 1).split('?').first;
      String decoded;
      try {
        decoded = utf8.decode(base64.decode(_pad(userInfo)));
      } catch (_) {
        decoded = Uri.decodeComponent(userInfo);
      }
      final ci = decoded.indexOf(':');
      if (ci > 0) {
        method   = decoded.substring(0, ci);
        password = decoded.substring(ci + 1);
      }
      final hc = hostPort.lastIndexOf(':');
      if (hc > 0) {
        server = hostPort.substring(0, hc);
        port   = int.tryParse(hostPort.substring(hc + 1)) ?? 0;
      }
    } else {
      final decoded = utf8.decode(base64.decode(_pad(main.split('?').first)));
      final a = decoded.lastIndexOf('@');
      if (a > 0) {
        final up = decoded.substring(0, a);
        final hp = decoded.substring(a + 1);
        final ci = up.indexOf(':');
        if (ci > 0) {
          method   = up.substring(0, ci);
          password = up.substring(ci + 1);
        }
        final hc = hp.lastIndexOf(':');
        if (hc > 0) {
          server = hp.substring(0, hc);
          port   = int.tryParse(hp.substring(hc + 1)) ?? 0;
        }
      }
    }

    return {
      'type': 'shadowsocks',
      'tag': tag,
      'server': server,
      'server_port': port,
      'method': method,
      'password': password,
    };
  }

  // ── Hysteria2 ─────────────────────────────────────────────────────────────

  static Map<String, dynamic> _hysteria2(String uri, {required String tag}) {
    final scheme  = uri.startsWith('hy2://') ? 'hy2' : 'hysteria2';
    final hashIdx = uri.lastIndexOf('#');
    final main    = uri.substring('$scheme://'.length,
        hashIdx > 0 ? hashIdx : uri.length);

    final atIdx = main.lastIndexOf('@');
    final pass  = atIdx >= 0 ? Uri.decodeComponent(main.substring(0, atIdx)) : '';
    final rest  = atIdx >= 0 ? main.substring(atIdx + 1) : main;
    final qIdx  = rest.indexOf('?');
    final hp    = qIdx > 0 ? rest.substring(0, qIdx) : rest;
    final qs    = qIdx > 0 ? rest.substring(qIdx + 1) : '';
    final params = Uri.splitQueryString(qs);

    final colonIdx = hp.lastIndexOf(':');
    final server   = colonIdx > 0 ? hp.substring(0, colonIdx) : hp;
    final port     = colonIdx > 0
        ? (int.tryParse(hp.substring(colonIdx + 1)) ?? 443)
        : 443;
    final sni      = params['sni'] ?? params['peer'] ?? server;
    final insecure = params['insecure'] == '1' ||
        params['skip-cert-verify'] == 'true';

    return {
      'type': 'hysteria2',
      'tag': tag,
      'server': server,
      'server_port': port,
      'password': pass,
      'tls': {
        'enabled': true,
        'server_name': sni,
        if (insecure) 'insecure': true,
      },
    };
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  static (String, String, int, Map<String, String>) _parseUserAtHostPort(
      String uri, String scheme) {
    final hashIdx = uri.lastIndexOf('#');
    final body    = uri.substring(scheme.length,
        hashIdx > 0 ? hashIdx : uri.length);
    final atIdx   = body.lastIndexOf('@');
    final user    = atIdx >= 0
        ? Uri.decodeComponent(body.substring(0, atIdx))
        : '';
    final rest    = atIdx >= 0 ? body.substring(atIdx + 1) : body;
    final qIdx    = rest.indexOf('?');
    final hp      = qIdx > 0 ? rest.substring(0, qIdx) : rest;
    final qs      = qIdx > 0 ? rest.substring(qIdx + 1) : '';
    final params  = Uri.splitQueryString(qs);
    final ci      = hp.lastIndexOf(':');
    final server  = ci > 0 ? hp.substring(0, ci) : hp;
    final port    = ci > 0 ? (int.tryParse(hp.substring(ci + 1)) ?? 0) : 0;
    return (user, server, port, params);
  }

  static void _applyTransport(Map<String, dynamic> out, String type,
      String path, String host) {
    final decoded = path.isNotEmpty ? Uri.decodeComponent(path) : '';
    if (type == 'ws') {
      out['transport'] = {
        'type': 'ws',
        if (decoded.isNotEmpty) 'path': decoded,
        if (host.isNotEmpty) 'headers': {'Host': host},
      };
    } else if (type == 'grpc') {
      out['transport'] = {
        'type': 'grpc',
        if (decoded.isNotEmpty) 'service_name': decoded,
      };
    } else if (type == 'h2') {
      out['transport'] = {
        'type': 'http',
        if (decoded.isNotEmpty) 'path': decoded,
        if (host.isNotEmpty) 'host': [host],
      };
    }
  }

  static String _pad(String s) {
    final r = s.length % 4;
    return r == 0 ? s : s + ('=' * (4 - r));
  }

  // ── File I/O ──────────────────────────────────────────────────────────────

  static Future<String> writeConfig(Map<String, dynamic> config) async {
    final file = File('${Directory.systemTemp.path}\\litchi_core.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config));
    return file.path;
  }
}

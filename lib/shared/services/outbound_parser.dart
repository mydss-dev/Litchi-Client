import 'dart:convert';

/// Converts a proxy URI string into a sing-box outbound map.
///
/// Supports: VMess, VLESS, Trojan, Shadowsocks, Hysteria2.
/// All methods are stateless — no I/O, no side effects.
abstract final class OutboundParser {
  /// Returns a sing-box outbound map for [uri], or null if unsupported.
  static Map<String, dynamic>? parse(String uri, {required String tag}) {
    try {
      if (uri.startsWith('vmess://'))    return _vmess(uri, tag: tag);
      if (uri.startsWith('vless://'))    return _vless(uri, tag: tag);
      if (uri.startsWith('trojan://'))   return _trojan(uri, tag: tag);
      if (uri.startsWith('ss://'))       return _ss(uri, tag: tag);
      if (uri.startsWith('hysteria2://') || uri.startsWith('hy2://')) {
        return _hysteria2(uri, tag: tag);
      }
    } catch (_) {}
    return null;
  }

  /// Converts one Clash `proxies:` entry into a sing-box outbound.
  static Map<String, dynamic>? parseClashProxy(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    try {
      final type = proxy['type']?.toString().toLowerCase() ?? '';
      return switch (type) {
        'vmess' => _vmessClash(proxy, tag: tag),
        'vless' => _vlessClash(proxy, tag: tag),
        'trojan' => _trojanClash(proxy, tag: tag),
        'ss' || 'shadowsocks' => _ssClash(proxy, tag: tag),
        'hysteria2' || 'hy2' => _hysteria2Clash(proxy, tag: tag),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  // ── VMess ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _vmess(String uri, {required String tag}) {
    final b64 = uri.substring('vmess://'.length);
    final j =
        jsonDecode(utf8.decode(base64.decode(_pad(b64))))
            as Map<String, dynamic>;

    final server = j['add']?.toString() ?? '';
    final port = int.tryParse(j['port']?.toString() ?? '') ?? 0;
    final uuid = j['id']?.toString() ?? '';
    final aid = int.tryParse(j['aid']?.toString() ?? '') ?? 0;
    final scy = j['scy']?.toString() ?? 'auto';
    final net = j['net']?.toString() ?? 'tcp';
    final tls = j['tls']?.toString() ?? '';
    final path = j['path']?.toString() ?? '';
    final host = j['host']?.toString() ?? '';

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
      out['tls'] = {'enabled': true, if (host.isNotEmpty) 'server_name': host};
    }

    return out;
  }

  // ── VLESS ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _vless(String uri, {required String tag}) {
    final (password, server, port, params) = _parseUserAtHostPort(
      uri,
      'vless://',
    );

    final security = params['security'] ?? '';
    final flow = params['flow'] ?? '';
    final sni = params['sni'] ?? params['servername'] ?? server;
    final type = params['type'] ?? 'tcp';
    final path = params['path'] ?? '';
    final host = params['host'] ?? '';
    final pbk = params['pbk'] ?? '';
    final sid = params['sid'] ?? '';
    final fp = params['fp'] ?? 'chrome';

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
    final (password, server, port, params) = _parseUserAtHostPort(
      uri,
      'trojan://',
    );

    final sni = params['sni'] ?? params['peer'] ?? server;
    final security = params['security'] ?? 'tls';
    final type = params['type'] ?? 'tcp';
    final path = params['path'] ?? '';
    final host = params['host'] ?? '';
    final fp = params['fp'] ?? '';

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
    final main = uri.substring(
      'ss://'.length,
      hashIdx > 0 ? hashIdx : uri.length,
    );

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
        method = decoded.substring(0, ci);
        password = decoded.substring(ci + 1);
      }
      final hc = hostPort.lastIndexOf(':');
      if (hc > 0) {
        server = hostPort.substring(0, hc);
        port = int.tryParse(hostPort.substring(hc + 1)) ?? 0;
      }
    } else {
      final decoded = utf8.decode(base64.decode(_pad(main.split('?').first)));
      final a = decoded.lastIndexOf('@');
      if (a > 0) {
        final up = decoded.substring(0, a);
        final hp = decoded.substring(a + 1);
        final ci = up.indexOf(':');
        if (ci > 0) {
          method = up.substring(0, ci);
          password = up.substring(ci + 1);
        }
        final hc = hp.lastIndexOf(':');
        if (hc > 0) {
          server = hp.substring(0, hc);
          port = int.tryParse(hp.substring(hc + 1)) ?? 0;
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
    final scheme = uri.startsWith('hy2://') ? 'hy2' : 'hysteria2';
    final hashIdx = uri.lastIndexOf('#');
    final main = uri.substring(
      '$scheme://'.length,
      hashIdx > 0 ? hashIdx : uri.length,
    );

    final atIdx = main.lastIndexOf('@');
    final pass = atIdx >= 0
        ? Uri.decodeComponent(main.substring(0, atIdx))
        : '';
    final rest = atIdx >= 0 ? main.substring(atIdx + 1) : main;
    final qIdx = rest.indexOf('?');
    final hp = qIdx > 0 ? rest.substring(0, qIdx) : rest;
    final qs = qIdx > 0 ? rest.substring(qIdx + 1) : '';
    final params = Uri.splitQueryString(qs);

    final colonIdx = hp.lastIndexOf(':');
    final server = colonIdx > 0 ? hp.substring(0, colonIdx) : hp;
    final port = colonIdx > 0
        ? (int.tryParse(hp.substring(colonIdx + 1)) ?? 443)
        : 443;
    final sni = params['sni'] ?? params['peer'] ?? server;
    final insecure =
        params['insecure'] == '1' || params['skip-cert-verify'] == 'true';

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

  static Map<String, dynamic> _vmessClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final out = <String, dynamic>{
      'type': 'vmess',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port']),
      'uuid': proxy['uuid']?.toString() ?? '',
      'security': proxy['cipher']?.toString() ?? 'auto',
      'alter_id': _int(proxy['alterId'] ?? proxy['alter-id']),
    };
    _applyClashTransport(out, proxy);
    if (_bool(proxy['tls'])) {
      final serverName = proxy['servername']?.toString() ?? '';
      out['tls'] = {
        'enabled': true,
        if (serverName.isNotEmpty) 'server_name': serverName,
        if (_bool(proxy['skip-cert-verify'])) 'insecure': true,
      };
    }
    return out;
  }

  static Map<String, dynamic> _vlessClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final reality = proxy['reality-opts'];
    final security = reality is Map
        ? 'reality'
        : (_bool(proxy['tls']) ? 'tls' : '');
    final query = <String, String>{
      if (security.isNotEmpty) 'security': security,
      if ((proxy['flow']?.toString() ?? '').isNotEmpty)
        'flow': proxy['flow'].toString(),
      if ((proxy['servername']?.toString() ?? '').isNotEmpty)
        'sni': proxy['servername'].toString(),
      if ((proxy['network']?.toString() ?? '').isNotEmpty)
        'type': proxy['network'].toString(),
      if ((proxy['client-fingerprint']?.toString() ?? '').isNotEmpty)
        'fp': proxy['client-fingerprint'].toString(),
      ..._clashTransportQuery(proxy),
    };
    if (reality is Map) {
      final publicKey = reality['public-key']?.toString() ?? '';
      final shortId = reality['short-id']?.toString() ?? '';
      if (publicKey.isNotEmpty) query['pbk'] = publicKey;
      if (shortId.isNotEmpty) query['sid'] = shortId;
    }
    final uri =
        'vless://${Uri.encodeComponent(proxy['uuid']?.toString() ?? '')}'
        '@${proxy['server']}:${_int(proxy['port'])}?${Uri(queryParameters: query).query}';
    return _vless(uri, tag: tag);
  }

  static Map<String, dynamic> _trojanClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final out = <String, dynamic>{
      'type': 'trojan',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port']),
      'password': proxy['password']?.toString() ?? '',
    };
    _applyClashTransport(out, proxy);
    out['tls'] = {
      'enabled': true,
      'server_name':
          proxy['sni']?.toString() ?? proxy['servername']?.toString() ?? '',
      if (_bool(proxy['skip-cert-verify'])) 'insecure': true,
    };
    return out;
  }

  static Map<String, dynamic> _ssClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    return {
      'type': 'shadowsocks',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port']),
      'method': proxy['cipher']?.toString() ?? 'aes-128-gcm',
      'password': proxy['password']?.toString() ?? '',
    };
  }

  static Map<String, dynamic> _hysteria2Clash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    return {
      'type': 'hysteria2',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port'] ?? 443),
      'password': proxy['password']?.toString() ?? '',
      'tls': {
        'enabled': true,
        'server_name':
            proxy['sni']?.toString() ?? proxy['servername']?.toString() ?? '',
        if (_bool(proxy['skip-cert-verify']) || _bool(proxy['insecure']))
          'insecure': true,
      },
    };
  }

  static (String, String, int, Map<String, String>) _parseUserAtHostPort(
    String uri,
    String scheme,
  ) {
    final hashIdx = uri.lastIndexOf('#');
    final body = uri.substring(
      scheme.length,
      hashIdx > 0 ? hashIdx : uri.length,
    );
    final atIdx = body.lastIndexOf('@');
    final user = atIdx >= 0
        ? Uri.decodeComponent(body.substring(0, atIdx))
        : '';
    final rest = atIdx >= 0 ? body.substring(atIdx + 1) : body;
    final qIdx = rest.indexOf('?');
    final hp = qIdx > 0 ? rest.substring(0, qIdx) : rest;
    final qs = qIdx > 0 ? rest.substring(qIdx + 1) : '';
    final params = Uri.splitQueryString(qs);
    final ci = hp.lastIndexOf(':');
    final server = ci > 0 ? hp.substring(0, ci) : hp;
    final port = ci > 0 ? (int.tryParse(hp.substring(ci + 1)) ?? 0) : 0;
    return (user, server, port, params);
  }

  static void _applyTransport(
    Map<String, dynamic> out,
    String type,
    String path,
    String host,
  ) {
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

  static int _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static Map<String, String> _clashTransportQuery(Map<String, dynamic> proxy) {
    final network = proxy['network']?.toString() ?? '';
    if (network == 'ws') {
      final headers = proxy['ws-headers'];
      return {
        if ((proxy['ws-path']?.toString() ?? '').isNotEmpty)
          'path': proxy['ws-path'].toString(),
        if (headers is Map && (headers['Host']?.toString() ?? '').isNotEmpty)
          'host': headers['Host'].toString(),
      };
    }
    if (network == 'grpc') {
      return {
        if ((proxy['grpc-service-name']?.toString() ?? '').isNotEmpty)
          'path': proxy['grpc-service-name'].toString(),
      };
    }
    return const {};
  }

  static void _applyClashTransport(
    Map<String, dynamic> out,
    Map<String, dynamic> proxy,
  ) {
    final query = _clashTransportQuery(proxy);
    _applyTransport(
      out,
      proxy['network']?.toString() ?? 'tcp',
      query['path'] ?? '',
      query['host'] ?? '',
    );
  }
}

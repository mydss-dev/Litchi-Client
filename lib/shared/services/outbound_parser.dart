import 'dart:convert';

/// Converts a proxy URI string into a sing-box outbound map.
///
/// Supports: VMess, VLESS, Trojan, Shadowsocks, Hysteria2.
/// All methods are stateless — no I/O, no side effects.
abstract final class OutboundParser {
  /// Returns a sing-box outbound map for [uri], or null if unsupported.
  ///
  /// When [allowInsecure] is false, any `tls.insecure` flag the node requested
  /// is stripped so certificate validation is always enforced.
  static Map<String, dynamic>? parse(
    String uri, {
    required String tag,
    bool allowInsecure = true,
  }) {
    try {
      final scheme = _scheme(uri);
      final out = switch (true) {
        _ when scheme == 'vmess' => _vmess(uri, tag: tag),
        _ when scheme == 'vless' => _vless(uri, tag: tag),
        _ when scheme == 'trojan' => _trojan(uri, tag: tag),
        _ when scheme == 'ss' => _ss(uri, tag: tag),
        _ when scheme == 'hysteria' => _hysteria(uri, tag: tag),
        _ when scheme == 'hysteria2' || scheme == 'hy2' => _hysteria2(
          uri,
          tag: tag,
        ),
        _ when scheme == 'tuic' => _tuic(uri, tag: tag),
        _ when scheme == 'anytls' => _anytls(uri, tag: tag),
        _ => null,
      };
      return _applyTlsPolicy(out, allowInsecure);
    } catch (_) {}
    return null;
  }

  /// Converts one Clash `proxies:` entry into a sing-box outbound.
  static Map<String, dynamic>? parseClashProxy(
    Map<String, dynamic> proxy, {
    required String tag,
    bool allowInsecure = true,
  }) {
    try {
      final type = proxy['type']?.toString().toLowerCase() ?? '';
      final out = switch (type) {
        'vmess' => _vmessClash(proxy, tag: tag),
        'vless' => _vlessClash(proxy, tag: tag),
        'trojan' => _trojanClash(proxy, tag: tag),
        'ss' || 'shadowsocks' => _ssClash(proxy, tag: tag),
        'hysteria' => _hysteriaClash(proxy, tag: tag),
        'hysteria2' || 'hy2' => _hysteria2Clash(proxy, tag: tag),
        'tuic' => _tuicClash(proxy, tag: tag),
        'anytls' => _anytlsClash(proxy, tag: tag),
        _ => null,
      };
      return _applyTlsPolicy(out, allowInsecure);
    } catch (_) {
      return null;
    }
  }

  /// Enforces the certificate-validation policy: drops `tls.insecure` when
  /// insecure nodes are disallowed.
  static Map<String, dynamic>? _applyTlsPolicy(
    Map<String, dynamic>? out,
    bool allowInsecure,
  ) {
    if (out == null || allowInsecure) return out;
    final tls = out['tls'];
    if (tls is Map) tls.remove('insecure');
    return out;
  }

  // ── VMess ─────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _vmess(String uri, {required String tag}) {
    final b64 = _afterScheme(uri);
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
    final (password, server, port, params) = _parseUserAtHostPort(uri);

    final security = params['security'] ?? '';
    final flow = params['flow'] ?? '';
    final sni =
        params['sni'] ?? params['servername'] ?? params['peer'] ?? server;
    final type = params['type'] ?? 'tcp';
    final path = params['path'] ?? '';
    final host = params['host'] ?? '';
    final pbk = params['pbk'] ?? '';
    final sid = params['sid'] ?? '';
    final fp = params['fp'] ?? 'chrome';
    final spiderX = params['spx'] ?? params['spiderx'] ?? '';

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
        'reality': {
          'enabled': true,
          'public_key': pbk,
          if (sid.isNotEmpty) 'short_id': sid,
          if (spiderX.isNotEmpty) 'spider_x': Uri.decodeComponent(spiderX),
        },
        'utls': {'enabled': true, 'fingerprint': fp},
      };
    }

    return out;
  }

  // ── Trojan ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _trojan(String uri, {required String tag}) {
    final (password, server, port, params) = _parseUserAtHostPort(uri);

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
      uri.indexOf('://') + 3,
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
      final hp = _splitHostPort(hostPort);
      server = hp.$1;
      port = hp.$2;
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
        final parsed = _splitHostPort(hp);
        server = parsed.$1;
        port = parsed.$2;
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
    final scheme = _scheme(uri);
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

    final parsed = _splitHostPort(hp, defaultPort: 443);
    final server = parsed.$1;
    final port = parsed.$2;
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

  // ── AnyTLS ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _hysteria(String uri, {required String tag}) {
    final (auth, server, port, params) = _parseUserAtHostPort(uri);
    final sni =
        params['sni'] ?? params['peer'] ?? params['servername'] ?? server;
    final fp = params['fp'] ?? params['client-fingerprint'] ?? '';
    final insecure =
        params['insecure'] == '1' || params['skip-cert-verify'] == 'true';
    final network = params['protocol'] ?? params['network'] ?? '';
    final out = <String, dynamic>{
      'type': 'hysteria',
      'tag': tag,
      'server': server,
      'server_port': port,
      'up': _bandwidth(params['up'] ?? params['upmbps'] ?? params['up_mbps']),
      'down': _bandwidth(
        params['down'] ?? params['downmbps'] ?? params['down_mbps'],
      ),
      if (auth.isNotEmpty) 'auth_str': auth,
      if ((params['obfs'] ?? '').isNotEmpty) 'obfs': params['obfs'],
      if (network.isNotEmpty) 'network': network,
      'tls': {
        'enabled': true,
        'server_name': sni,
        if (insecure) 'insecure': true,
        if (fp.isNotEmpty) 'utls': {'enabled': true, 'fingerprint': fp},
      },
    };
    final alpn = _stringListParam(params['alpn']);
    if (alpn.isNotEmpty) (out['tls'] as Map<String, dynamic>)['alpn'] = alpn;
    return out;
  }

  static Map<String, dynamic> _tuic(String uri, {required String tag}) {
    final (user, server, port, params) = _parseUserAtHostPort(uri);
    final parts = user.split(':');
    final uuid = parts.isNotEmpty ? parts.first : '';
    final password = parts.length > 1 ? parts.sublist(1).join(':') : '';
    final sni =
        params['sni'] ?? params['servername'] ?? params['peer'] ?? server;
    final fp = params['fp'] ?? params['client-fingerprint'] ?? '';
    final insecure =
        params['insecure'] == '1' || params['skip-cert-verify'] == 'true';
    final congestion =
        params['congestion_control'] ?? params['congestion-control'] ?? '';
    final udpRelay = params['udp_relay_mode'] ?? params['udp-relay-mode'] ?? '';
    final out = <String, dynamic>{
      'type': 'tuic',
      'tag': tag,
      'server': server,
      'server_port': port,
      'uuid': uuid,
      if (password.isNotEmpty) 'password': password,
      if (congestion.isNotEmpty) 'congestion_control': congestion,
      if (udpRelay.isNotEmpty) 'udp_relay_mode': udpRelay,
      if ((params['network'] ?? '').isNotEmpty) 'network': params['network'],
      'tls': {
        'enabled': true,
        'server_name': sni,
        if (insecure) 'insecure': true,
        if (fp.isNotEmpty) 'utls': {'enabled': true, 'fingerprint': fp},
      },
    };
    final alpn = _stringListParam(params['alpn']);
    if (alpn.isNotEmpty) (out['tls'] as Map<String, dynamic>)['alpn'] = alpn;
    return out;
  }

  static Map<String, dynamic> _anytls(String uri, {required String tag}) {
    final (password, server, port, params) = _parseUserAtHostPort(uri);
    final sni =
        params['sni'] ?? params['servername'] ?? params['peer'] ?? server;
    final fp = params['fp'] ?? params['client-fingerprint'] ?? '';
    final insecure =
        params['insecure'] == '1' ||
        params['insecure'] == 'true' ||
        params['skip-cert-verify'] == 'true';

    final out = <String, dynamic>{
      'type': 'anytls',
      'tag': tag,
      'server': server,
      'server_port': port,
      'password': password,
      'tls': {
        'enabled': true,
        'server_name': sni,
        if (insecure) 'insecure': true,
        if (fp.isNotEmpty) 'utls': {'enabled': true, 'fingerprint': fp},
      },
    };
    _applyAnyTlsSessionOptions(out, params);
    final alpn = _stringListParam(params['alpn']);
    if (alpn.isNotEmpty) (out['tls'] as Map<String, dynamic>)['alpn'] = alpn;
    return out;
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
    final reality = proxy['reality-opts'] ?? proxy['reality_opts'];
    final security = reality is Map
        ? 'reality'
        : (_bool(proxy['tls']) ? 'tls' : '');
    final query = <String, String>{
      if (security.isNotEmpty) 'security': security,
      if ((proxy['flow']?.toString() ?? '').isNotEmpty)
        'flow': proxy['flow'].toString(),
      if (_firstProxyString(proxy, ['servername', 'sni', 'peer']) != null)
        'sni': _firstProxyString(proxy, ['servername', 'sni', 'peer'])!,
      if ((proxy['network']?.toString() ?? '').isNotEmpty)
        'type': proxy['network'].toString().toLowerCase(),
      if (_firstProxyString(proxy, [
            'client-fingerprint',
            'fingerprint',
            'fp',
          ]) !=
          null)
        'fp': _firstProxyString(proxy, [
          'client-fingerprint',
          'fingerprint',
          'fp',
        ])!,
      ..._clashTransportQuery(proxy),
    };
    if (reality is Map) {
      final publicKey = reality['public-key']?.toString() ?? '';
      final shortId = reality['short-id']?.toString() ?? '';
      final spiderX =
          reality['spider-x']?.toString() ??
          reality['spiderX']?.toString() ??
          '';
      if (publicKey.isNotEmpty) query['pbk'] = publicKey;
      if (shortId.isNotEmpty) query['sid'] = shortId;
      if (spiderX.isNotEmpty) query['spx'] = spiderX;
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

  static Map<String, dynamic> _hysteriaClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final sni =
        _firstProxyString(proxy, ['sni', 'servername', 'peer']) ??
        proxy['server']?.toString() ??
        '';
    final fp = _firstProxyString(proxy, [
      'client-fingerprint',
      'fingerprint',
      'fp',
    ]);
    final out = <String, dynamic>{
      'type': 'hysteria',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port'] ?? 443),
      'up': _bandwidth(
        proxy['up'] ?? proxy['up-mbps'] ?? proxy['up_mbps'] ?? proxy['upmbps'],
      ),
      'down': _bandwidth(
        proxy['down'] ??
            proxy['down-mbps'] ??
            proxy['down_mbps'] ??
            proxy['downmbps'],
      ),
      if ((proxy['auth-str']?.toString() ?? '').isNotEmpty)
        'auth_str': proxy['auth-str'].toString()
      else if ((proxy['auth_str']?.toString() ?? '').isNotEmpty)
        'auth_str': proxy['auth_str'].toString()
      else if ((proxy['password']?.toString() ?? '').isNotEmpty)
        'auth_str': proxy['password'].toString()
      else if ((proxy['auth']?.toString() ?? '').isNotEmpty)
        'auth': proxy['auth'].toString(),
      if ((proxy['obfs']?.toString() ?? '').isNotEmpty)
        'obfs': proxy['obfs'].toString(),
      if ((proxy['protocol']?.toString() ?? proxy['network']?.toString() ?? '')
          .isNotEmpty)
        'network': proxy['protocol']?.toString() ?? proxy['network'].toString(),
      'tls': {
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
        if (_bool(proxy['skip-cert-verify']) || _bool(proxy['insecure']))
          'insecure': true,
        if (fp != null) 'utls': {'enabled': true, 'fingerprint': fp},
        if (_stringListObject(proxy['alpn']).isNotEmpty)
          'alpn': _stringListObject(proxy['alpn']),
      },
    };
    return out;
  }

  static Map<String, dynamic> _tuicClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final sni =
        _firstProxyString(proxy, ['sni', 'servername', 'peer']) ??
        proxy['server']?.toString() ??
        '';
    final fp = _firstProxyString(proxy, [
      'client-fingerprint',
      'fingerprint',
      'fp',
    ]);
    return {
      'type': 'tuic',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port'] ?? 443),
      'uuid': proxy['uuid']?.toString() ?? '',
      if ((proxy['password']?.toString() ?? '').isNotEmpty)
        'password': proxy['password'].toString(),
      if ((proxy['congestion-controller']?.toString() ??
              proxy['congestion_control']?.toString() ??
              proxy['congestion-control']?.toString() ??
              '')
          .isNotEmpty)
        'congestion_control':
            proxy['congestion-controller']?.toString() ??
            proxy['congestion_control']?.toString() ??
            proxy['congestion-control'].toString(),
      if ((proxy['udp-relay-mode']?.toString() ??
              proxy['udp_relay_mode']?.toString() ??
              '')
          .isNotEmpty)
        'udp_relay_mode':
            proxy['udp-relay-mode']?.toString() ??
            proxy['udp_relay_mode'].toString(),
      if ((proxy['network']?.toString() ?? '').isNotEmpty)
        'network': proxy['network'].toString(),
      'tls': {
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
        if (_bool(proxy['skip-cert-verify']) || _bool(proxy['insecure']))
          'insecure': true,
        if (fp != null) 'utls': {'enabled': true, 'fingerprint': fp},
        if (_stringListObject(proxy['alpn']).isNotEmpty)
          'alpn': _stringListObject(proxy['alpn']),
      },
    };
  }

  static Map<String, dynamic> _anytlsClash(
    Map<String, dynamic> proxy, {
    required String tag,
  }) {
    final sni =
        _firstProxyString(proxy, ['sni', 'servername', 'peer']) ??
        proxy['server']?.toString() ??
        '';
    final fp = _firstProxyString(proxy, [
      'client-fingerprint',
      'fingerprint',
      'fp',
    ]);
    final out = <String, dynamic>{
      'type': 'anytls',
      'tag': tag,
      'server': proxy['server']?.toString() ?? '',
      'server_port': _int(proxy['port']),
      'password': proxy['password']?.toString() ?? '',
      'tls': {
        'enabled': true,
        if (sni.isNotEmpty) 'server_name': sni,
        if (_bool(proxy['skip-cert-verify']) || _bool(proxy['insecure']))
          'insecure': true,
        if (fp != null) 'utls': {'enabled': true, 'fingerprint': fp},
        if (_stringListObject(proxy['alpn']).isNotEmpty)
          'alpn': _stringListObject(proxy['alpn']),
      },
    };
    _applyAnyTlsSessionOptions(out, {
      if (proxy['idle-session-check-interval'] != null)
        'idle-session-check-interval': proxy['idle-session-check-interval']
            .toString(),
      if (proxy['idle_session_check_interval'] != null)
        'idle_session_check_interval': proxy['idle_session_check_interval']
            .toString(),
      if (proxy['idle-session-timeout'] != null)
        'idle-session-timeout': proxy['idle-session-timeout'].toString(),
      if (proxy['idle_session_timeout'] != null)
        'idle_session_timeout': proxy['idle_session_timeout'].toString(),
      if (proxy['min-idle-session'] != null)
        'min-idle-session': proxy['min-idle-session'].toString(),
      if (proxy['min_idle_session'] != null)
        'min_idle_session': proxy['min_idle_session'].toString(),
    });
    return out;
  }

  static (String, String, int, Map<String, String>) _parseUserAtHostPort(
    String uri,
  ) {
    final hashIdx = uri.lastIndexOf('#');
    final body = uri.substring(
      uri.indexOf('://') + 3,
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
    final parsed = _splitHostPort(hp);
    final server = parsed.$1;
    final port = parsed.$2;
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

  static void _applyAnyTlsSessionOptions(
    Map<String, dynamic> out,
    Map<String, String> params,
  ) {
    final checkInterval =
        params['idle_session_check_interval'] ??
        params['idle-session-check-interval'];
    final timeout =
        params['idle_session_timeout'] ?? params['idle-session-timeout'];
    final minIdle = params['min_idle_session'] ?? params['min-idle-session'];
    if (checkInterval != null && checkInterval.isNotEmpty) {
      out['idle_session_check_interval'] = _durationLike(checkInterval);
    }
    if (timeout != null && timeout.isNotEmpty) {
      out['idle_session_timeout'] = _durationLike(timeout);
    }
    final min = int.tryParse(minIdle ?? '');
    if (min != null) out['min_idle_session'] = min;
  }

  static String _durationLike(String value) {
    final text = value.trim();
    if (RegExp(r'^\d+$').hasMatch(text)) return '${text}s';
    return text;
  }

  static String _bandwidth(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '100 Mbps';
    if (RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return '$text Mbps';
    return text;
  }

  static List<String> _stringListParam(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static List<String> _stringListObject(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String) return _stringListParam(value);
    return const [];
  }

  static Map<String, String> _clashTransportQuery(Map<String, dynamic> proxy) {
    final network = proxy['network']?.toString().toLowerCase() ?? '';
    if (network == 'ws') {
      final headers = proxy['ws-headers'];
      final opts = proxy['ws-opts'];
      final optsMap = opts is Map ? opts : const {};
      final optsHeaders = optsMap['headers'];
      return {
        if (_firstProxyString(proxy, ['ws-path']) != null)
          'path': _firstProxyString(proxy, ['ws-path'])!,
        if ((optsMap['path']?.toString() ?? '').isNotEmpty)
          'path': optsMap['path'].toString(),
        if (headers is Map && (headers['Host']?.toString() ?? '').isNotEmpty)
          'host': headers['Host'].toString(),
        if (headers is Map && (headers['host']?.toString() ?? '').isNotEmpty)
          'host': headers['host'].toString(),
        if (optsHeaders is Map &&
            (optsHeaders['Host']?.toString() ?? '').isNotEmpty)
          'host': optsHeaders['Host'].toString(),
        if (optsHeaders is Map &&
            (optsHeaders['host']?.toString() ?? '').isNotEmpty)
          'host': optsHeaders['host'].toString(),
      };
    }
    if (network == 'grpc') {
      final opts = proxy['grpc-opts'];
      final optsMap = opts is Map ? opts : const {};
      return {
        if (_firstProxyString(proxy, ['grpc-service-name']) != null)
          'path': _firstProxyString(proxy, ['grpc-service-name'])!,
        if ((optsMap['grpc-service-name']?.toString() ?? '').isNotEmpty)
          'path': optsMap['grpc-service-name'].toString(),
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

  static String _scheme(String uri) {
    final i = uri.indexOf('://');
    return i <= 0 ? '' : uri.substring(0, i).toLowerCase();
  }

  static String _afterScheme(String uri) =>
      uri.substring(uri.indexOf('://') + 3);

  static (String, int) _splitHostPort(String hostPort, {int defaultPort = 0}) {
    final clean = hostPort.split('?').first;
    if (clean.startsWith('[')) {
      final end = clean.indexOf(']');
      if (end > 0) {
        final host = clean.substring(1, end);
        final rest = clean.substring(end + 1);
        final port = rest.startsWith(':')
            ? (int.tryParse(rest.substring(1)) ?? defaultPort)
            : defaultPort;
        return (host, port);
      }
    }
    final colon = clean.lastIndexOf(':');
    if (colon > 0 && clean.indexOf(':') == colon) {
      return (
        clean.substring(0, colon),
        int.tryParse(clean.substring(colon + 1)) ?? defaultPort,
      );
    }
    return (clean, defaultPort);
  }

  static String? _firstProxyString(
    Map<dynamic, dynamic> proxy,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = proxy[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}

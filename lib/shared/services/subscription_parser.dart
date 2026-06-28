import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../models/api_models.dart';
import 'outbound_parser.dart';

/// Parses subscription body text into a list of [RemoteNode].
///
/// Supports Base64-encoded URI lists, plain URI lists, and Clash YAML.
/// All methods are stateless and synchronous — no network access.
abstract final class SubscriptionParser {
  static const int maxBodyBytes = 4 * 1024 * 1024;
  static const int maxNodes = 5000;

  static List<RemoteNode> parse(String body) {
    return parseProfile(body).nodes;
  }

  /// Parses subscription text and returns the full profile including rules and
  /// rule-providers when the server responds with Clash YAML.
  static ParsedSubscriptionProfile parseProfile(String body) {
    if (utf8.encode(body).length > maxBodyBytes) {
      return const ParsedSubscriptionProfile(nodes: []);
    }

    String content = body;
    // Try base64 decode first — subscription providers often wrap Clash YAML.
    if (!body.contains('\nproxies:') && !body.startsWith('proxies:')) {
      try {
        final decoded = utf8.decode(base64.decode(_pad(body)));
        if (decoded.contains('\nproxies:') || decoded.startsWith('proxies:')) {
          content = decoded;
        }
      } catch (_) {}
    }

    if (content.contains('\nproxies:') || content.startsWith('proxies:')) {
      return _parseFullClashProfile(content);
    }
    if (content.contains('://')) {
      return ParsedSubscriptionProfile(nodes: _parseUriList(content));
    }
    return const ParsedSubscriptionProfile(nodes: []);
  }

  // ── Clash YAML ────────────────────────────────────────────────────────────

  /// Clash proxy types that [MihomoConfig._supportedTypes] can pass through
  /// as-is.  Must stay in sync with that list.
  static const _supportedClashTypes = {
    'vmess',
    'vless',
    'trojan',
    'ss',
    'shadowsocks',
    'hysteria',
    'hysteria2',
    'hy2',
    'tuic',
    'anytls',
    'socks5',
    'http',
    'wireguard',
    'ssh',
    'mieru',
    'snell',
  };

  /// Validates a raw Clash proxy entry without normalising it — the entry is
  /// passed through to mihomo in its original form.  [OutboundParser] is only
  /// used for URI-scheme nodes; Clash entries only need a type/server/name
  /// sanity check so socks5/http/wireguard/ssh/etc. are not incorrectly dropped.
  static bool _isSupportedClashProxy(Map<String, dynamic> proxy) {
    final type = '${proxy['type'] ?? ''}'.toLowerCase();
    if (!_supportedClashTypes.contains(type)) return false;
    final name = '${proxy['name'] ?? ''}'.trim();
    if (name.isEmpty) return false;
    final server = '${proxy['server'] ?? ''}'.trim();
    if (server.isEmpty) return false;
    return true;
  }

  /// Parses a full Clash YAML subscription into proxy nodes, rules, and
  /// rule-providers. The server returns this when the request UA contains
  /// "clash" (e.g. ClashMetaForLitchi/1.0).
  static ParsedSubscriptionProfile _parseFullClashProfile(String content) {
    final nodes = <RemoteNode>[];
    final rules = <String>[];
    final ruleProviders = <String, dynamic>{};
    int id = 1;
    try {
      final doc = loadYaml(content);
      if (doc is! YamlMap) {
        return const ParsedSubscriptionProfile(nodes: []);
      }

      // ── proxies ──────────────────────────────────────────────────────────
      final proxies = doc['proxies'];
      if (proxies is YamlList) {
        for (final proxy in proxies) {
          if (nodes.length >= maxNodes) break;
          if (proxy is! YamlMap) continue;
          final rawOutbound = <String, dynamic>{};
          for (final entry in proxy.entries) {
            rawOutbound[entry.key.toString()] = _plainYamlValue(entry.value);
          }
          if (!_isSupportedClashProxy(rawOutbound)) continue;
          final name = proxy['name']?.toString() ?? 'Node $id';
          final server = proxy['server']?.toString() ?? '';
          final port = int.tryParse(proxy['port']?.toString() ?? '') ?? 0;
          final rate = double.tryParse(proxy['rate']?.toString() ?? '') ?? 1.0;
          if (name.isNotEmpty) {
            nodes.add(
              RemoteNode(
                id: id++,
                name: name,
                server: server,
                port: port,
                rate: rate,
                rawOutbound: rawOutbound,
              ),
            );
          }
        }
      }

      // ── rules ────────────────────────────────────────────────────────────
      final rawRules = doc['rules'];
      if (rawRules is YamlList) {
        for (final rule in rawRules) {
          final text = rule?.toString().trim() ?? '';
          if (text.isNotEmpty) rules.add(_normalizeRulePolicy(text));
        }
      }

      // ── rule-providers ───────────────────────────────────────────────────
      final rawProviders = doc['rule-providers'];
      if (rawProviders is YamlMap) {
        for (final entry in rawProviders.entries) {
          final key = entry.key.toString();
          final value = entry.value;
          if (value is YamlMap) {
            final plain = _plainYamlValue(value);
            if (plain is Map) {
              final safe = _sanitizeRuleProvider(plain, key);
              if (safe != null) ruleProviders[key] = safe;
            }
          }
        }
      }
    } catch (_) {}

    return ParsedSubscriptionProfile(
      nodes: nodes,
      rules: rules,
      ruleProviders: ruleProviders,
    );
  }

  /// Maps custom policy group names in server-side rules to the client's
  /// canonical PROXY group.
  ///
  /// Clash rules have the policy at index 2 (the third comma-separated
  /// field).  Extra modifiers such as `no-resolve` may appear after it:
  ///
  ///     IP-CIDR,1.1.1.1/32,DIRECT,no-resolve
  ///     DOMAIN-SUFFIX,google.com,PROXY
  ///
  /// This method reads the field at index 2 and leaves the rest alone.
  /// Built-in actions (DIRECT, REJECT, REJECT-DROP, PASS, GLOBAL, PROXY)
  /// pass through unchanged; unrecognised values are mapped to PROXY.
  static String _normalizeRulePolicy(String rule) {
    final parts = rule.split(',').map((e) => e.trim()).toList();
    if (parts.length < 3) return rule;

    const builtin = {
      'DIRECT',
      'REJECT',
      'REJECT-DROP',
      'PASS',
      'GLOBAL',
      'PROXY',
    };

    const policyIndex = 2;
    final policy = parts[policyIndex].toUpperCase();

    if (!builtin.contains(policy)) {
      parts[policyIndex] = 'PROXY';
    }

    return parts.join(',');
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
      if (node != null) {
        nodes.add(node);
        id++;
      }
    }
    return nodes;
  }

  static RemoteNode? _parseUri(String uri, int id) {
    try {
      final scheme = _scheme(uri);
      if (!isSupportedUri(uri)) return null;
      if (scheme == 'vmess') return _parseVmess(uri, id);
      if (scheme == 'vless') return _parseHostFrag(uri, id);
      if (scheme == 'trojan') return _parseHostFrag(uri, id);
      if (scheme == 'hysteria' || scheme == 'hysteria2' || scheme == 'hy2') {
        return _parseHostFrag(uri, id);
      }
      if (scheme == 'tuic') return _parseHostFrag(uri, id);
      if (scheme == 'anytls') return _parseHostFrag(uri, id);
      if (scheme == 'ss') return _parseSS(uri, id);
    } catch (_) {}
    return null;
  }

  static bool isSupportedUri(String uri) {
    final scheme = _scheme(uri);
    if (!const {
      'vmess',
      'vless',
      'trojan',
      'ss',
      'hysteria',
      'hysteria2',
      'hy2',
      'tuic',
      'anytls',
    }.contains(scheme)) {
      return false;
    }
    return OutboundParser.parse(uri, tag: 'probe') != null;
  }

  static RemoteNode _parseVmess(String uri, int id) {
    final b64 = uri.substring(uri.indexOf('://') + 3);
    final j =
        jsonDecode(utf8.decode(base64.decode(_pad(b64))))
            as Map<String, dynamic>;
    return RemoteNode(
      id: id,
      name: _decodeStr(j['ps']?.toString()) ?? 'VMess $id',
      server: j['add']?.toString() ?? '',
      port: int.tryParse(j['port']?.toString() ?? '') ?? 0,
      rate: double.tryParse(j['rate']?.toString() ?? '') ?? 1.0,
      rawUri: uri,
    );
  }

  static RemoteNode _parseHostFrag(String uri, int id) {
    final hashIdx = uri.lastIndexOf('#');
    final name = hashIdx >= 0
        ? (_decodeStr(uri.substring(hashIdx + 1)) ?? 'Node $id')
        : 'Node $id';
    final body = uri.substring(
      uri.indexOf('://') + 3,
      hashIdx > 0 ? hashIdx : uri.length,
    );
    final authority = body.split('?').first;
    final atIdx = authority.lastIndexOf('@');
    final hostPort = atIdx >= 0 ? authority.substring(atIdx + 1) : authority;
    final parsed = _splitHostPort(hostPort);
    final server = parsed.$1;
    final port = parsed.$2;
    return RemoteNode(
      id: id,
      name: name,
      server: server,
      port: port,
      rate: 1.0,
      rawUri: uri,
    );
  }

  static RemoteNode _parseSS(String uri, int id) {
    final hashIdx = uri.lastIndexOf('#');
    final name = hashIdx >= 0
        ? (_decodeStr(uri.substring(hashIdx + 1)) ?? 'SS $id')
        : 'SS $id';
    String server = '';
    int port = 0;
    try {
      final body = uri.substring(
        uri.indexOf('://') + 3,
        hashIdx > 0 ? hashIdx : uri.length,
      );
      final atIdx = body.lastIndexOf('@');
      if (atIdx >= 0) {
        final hp = body.substring(atIdx + 1);
        final parsed = _splitHostPort(hp);
        server = parsed.$1;
        port = parsed.$2;
      } else {
        final decoded = utf8.decode(base64.decode(_pad(body)));
        final a = decoded.lastIndexOf('@');
        if (a >= 0) {
          final hp = decoded.substring(a + 1);
          final parsed = _splitHostPort(hp);
          server = parsed.$1;
          port = parsed.$2;
        }
      }
    } catch (_) {}
    return RemoteNode(
      id: id,
      name: name,
      server: server,
      port: port,
      rate: 1.0,
      rawUri: uri,
    );
  }

  // ── Rule-provider sanitization ────────────────────────────────────────────

  /// Sanitises one subscription-supplied `rule-providers` entry.
  ///
  /// A subscription is only semi-trusted (a compromised panel or a MITM'd
  /// fetch can inject entries), so the core must never be told to:
  ///   * fetch a rule list over plaintext http, or
  ///   * write a provider file outside its own data directory via a traversal
  ///     or absolute `path`.
  ///
  /// A non-https provider URL is dropped (it cannot be made safe). A dangerous
  /// `path` is *confined* to a safe default under `providers/` instead of being
  /// dropped, so a benign config that merely uses an unusual path still works
  /// and rules referencing the provider do not break core startup.
  static Map<String, dynamic>? _sanitizeRuleProvider(Map provider, String key) {
    final out = <String, dynamic>{
      for (final entry in provider.entries) entry.key.toString(): entry.value,
    };

    final type = '${out['type'] ?? ''}'.toLowerCase();
    if (type == 'http' || out.containsKey('url')) {
      final url = '${out['url'] ?? ''}'.trim();
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return null;
      }
      out['url'] = url;
    }

    if (out['path'] != null) {
      out['path'] = _confineProviderPath('${out['path']}', key);
    }

    return out;
  }

  /// Returns a confined relative provider path under `providers/`. Absolute
  /// paths or `..` traversal are replaced with a safe default rather than
  /// dropped.
  static String _confineProviderPath(String raw, String fallbackName) {
    var p = raw.trim().replaceAll('\\', '/');
    final isAbsolute = p.startsWith('/') || RegExp(r'^[a-zA-Z]:').hasMatch(p);
    if (p.startsWith('./')) p = p.substring(2);
    final segments = p.split('/').where((s) => s.isNotEmpty).toList();
    final hasTraversal = segments.contains('..');
    final safeFallback =
        'providers/${_safeFileStem(fallbackName)}.yaml';
    if (p.isEmpty || isAbsolute || hasTraversal || segments.isEmpty) {
      return safeFallback;
    }
    if (segments.first == 'providers') return segments.join('/');
    return 'providers/${segments.join('/')}';
  }

  static String _safeFileStem(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').trim();
    return cleaned.isEmpty ? 'provider' : cleaned;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _decodeStr(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  static String _scheme(String uri) {
    final i = uri.indexOf('://');
    return i <= 0 ? '' : uri.substring(0, i).toLowerCase();
  }

  static (String, int) _splitHostPort(String hostPort) {
    final clean = hostPort.split('?').first;
    if (clean.startsWith('[')) {
      final end = clean.indexOf(']');
      if (end > 0) {
        final rest = clean.substring(end + 1);
        return (
          clean.substring(1, end),
          rest.startsWith(':') ? (int.tryParse(rest.substring(1)) ?? 0) : 0,
        );
      }
    }
    final colon = clean.lastIndexOf(':');
    if (colon > 0 && clean.indexOf(':') == colon) {
      return (
        clean.substring(0, colon),
        int.tryParse(clean.substring(colon + 1)) ?? 0,
      );
    }
    return (clean, 0);
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

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import 'outbound_parser.dart';

enum RuleSetState { normal, missing, degraded }

class RuleSetStatus {
  const RuleSetStatus(
    this.state, {
    this.missingFiles = const [],
    this.directory = '',
  });

  final RuleSetState state;
  final List<String> missingFiles;
  final String directory;

  bool get isNormal => state == RuleSetState.normal;
  bool get isDegraded => state == RuleSetState.degraded;
}

/// Generates sing-box JSON configs from parsed node lists.
///
/// Architecture:
/// - All nodes are written as outbounds with unique tags.
/// - A `urltest` outbound (自动选择) tests real proxy latency every 10 min.
/// - A `selector` outbound (PROXY) lets the user pick a node or auto-select.
/// - Clash-compatible REST API enables runtime node switching without restart.
/// - Rule mode uses remote rule_set files (OSS) for CN bypass + ad blocking.
abstract final class SingboxConfig {
  static const int defaultPort = 7890;
  static const int defaultApiPort = 9090;
  static const String selectorTag = 'PROXY';
  static const String autoSelectTag = 'AUTO';
  static const String delayTestUrl = 'https://cp.cloudflare.com/generate_204';
  static const List<String> requiredRuleFiles = [
    'geosite-cn.srs',
    'geoip-cn.srs',
    'geosite-category-ads-all.srs',
  ];

  static String appDataDir() {
    final base =
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    return '$base\\Litchi';
  }

  // Rule set files are bundled next to the exe under rules\ in production.
  // During development they won't exist — _ruleSets() falls back to OSS.
  static String get _rulesDir {
    final sep = Platform.pathSeparator;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir${sep}rules';
  }

  static String get ruleDirectory => _rulesDir;

  static List<String> missingRuleFiles() => [
    for (final file in requiredRuleFiles)
      if (!File('$_rulesDir${Platform.pathSeparator}$file').existsSync()) file,
  ];

  static RuleSetStatus ruleStatus(ProxyMode proxyMode) {
    final missing = missingRuleFiles();
    if (missing.isEmpty) {
      return const RuleSetStatus(RuleSetState.normal);
    }
    return RuleSetStatus(
      proxyMode == ProxyMode.rule
          ? RuleSetState.degraded
          : RuleSetState.missing,
      missingFiles: missing,
      directory: _rulesDir,
    );
  }

  static bool get _hasLocalRules => missingRuleFiles().isEmpty;

  /// Random secret generated once per process — required by Clash API.
  static final String apiSecret = _generateSecret();
  static String _generateSecret() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Build a complete multi-node config.
  ///
  /// [nodes]       — all available nodes (skips any with empty rawUri).
  /// [selectedTag] — the node tag that should be active on first start;
  ///                 empty string means start with 自动选择.
  /// [port]        — mixed inbound port (HTTP + SOCKS5).
  /// [apiPort]     — Clash-compatible REST API port for runtime switching.
  /// [proxyMode]   — rule | global | direct
  /// [dnsMode]     — '系统 DNS' | 'Cloudflare' | 'Google'
  /// [networkMode] — system | tun
  ///
  /// Returns null only when [nodes] is empty or all URIs are unparseable.
  static Map<String, dynamic>? buildFullConfig(
    List<NodeModel> nodes, {
    required String selectedTag,
    int port = defaultPort,
    int apiPort = defaultApiPort,
    ProxyMode proxyMode = ProxyMode.rule,
    String dnsMode = '系统 DNS',
    NetworkMode networkMode = NetworkMode.system,
    bool allowInsecure = true,
  }) {
    final outbounds = <Map<String, dynamic>>[];
    final tags = <String>[];

    for (final n in nodes) {
      final ob = n.rawUri.isNotEmpty
          ? OutboundParser.parse(
              n.rawUri,
              tag: _nodeTag(n),
              allowInsecure: allowInsecure,
            )
          : (n.rawOutbound == null
                ? null
                : OutboundParser.parseClashProxy(
                    n.rawOutbound!,
                    tag: _nodeTag(n),
                    allowInsecure: allowInsecure,
                  ));
      if (ob == null) continue;
      outbounds.add(ob);
      tags.add(_nodeTag(n));
    }

    if (tags.isEmpty) return null;

    // Determine the active outbound for the selector's default.
    // Empty / unknown selectedTag → start with auto-select.
    final defaultOutbound = tags.contains(selectedTag)
        ? selectedTag
        : autoSelectTag;

    // ── Route & rule_set ────────────────────────────────────────────────────
    final String routeFinal;
    final List<Map<String, dynamic>> routeRules;
    final List<Map<String, dynamic>> ruleSets;

    switch (proxyMode) {
      case ProxyMode.global:
        routeFinal = selectorTag;
        routeRules = [
          {
            // Explicit CIDR list instead of ip_is_private: Go's IsPrivate() omits
            // 198.18.0.0/15 (RFC 2544 benchmark range), which many proxy servers
            // use.  Without this, node-1's VLESS connection to 198.18.x.x enters
            // TUN and loops back through PROXY → routing loop / TLS failure.
            'ip_cidr': [
              '10.0.0.0/8',
              '172.16.0.0/12',
              '192.168.0.0/16',
              '127.0.0.0/8',
              '169.254.0.0/16',
              '100.64.0.0/10',
              '198.18.0.0/15',
              'fc00::/7',
              '::1/128',
              'fe80::/10',
            ],
            'outbound': 'direct',
          },
        ];
        ruleSets = [];

      case ProxyMode.direct:
        routeFinal = 'direct';
        routeRules = [];
        ruleSets = [];

      case ProxyMode.rule:
        routeFinal = selectorTag;
        routeRules = [
          if (_hasLocalRules) ...[
            {'rule_set': 'geosite-ads', 'outbound': 'block'},
            {
              'rule_set': ['geosite-cn', 'geoip-cn'],
              'outbound': 'direct',
            },
          ],
          {
            'ip_cidr': [
              '10.0.0.0/8',
              '172.16.0.0/12',
              '192.168.0.0/16',
              '127.0.0.0/8',
              '169.254.0.0/16',
              '100.64.0.0/10',
              '198.18.0.0/15',
              'fc00::/7',
              '::1/128',
              'fe80::/10',
            ],
            'outbound': 'direct',
          },
        ];
        ruleSets = _ruleSets();
    }

    // ── DNS servers ─────────────────────────────────────────────────────────
    // cn-dns: always present; used for CN domains and routing-engine queries.
    // remote-dns: foreign / encrypted resolver (choice depends on dnsMode).
    final Map<String, dynamic> remoteDnsServer;
    switch (dnsMode) {
      case 'Google':
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'https',
          'server': '8.8.8.8',
          // Use auto-select group so DNS always uses the fastest working node.
          // Avoids DNS failure when the user's manually-selected node is down.
          // URLTest doesn't need local DNS (proxy server resolves on its side).
          'detour': autoSelectTag,
        };
      default: // '系统 DNS' and 'Cloudflare' both use Cloudflare DoH
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'https',
          'server': '1.1.1.1',
          'detour': autoSelectTag,
        };
    }

    // DNS rules only matter in rule mode; global/direct uses the final server.
    // Note: routing-loop prevention is handled by default_domain_resolver in
    // route, so no outbound:any rule is needed (deprecated in sing-box v1.9+).
    // Must mirror the _hasLocalRules guard on route rules — referencing a
    // rule_set that isn't defined makes sing-box exit with FATAL at startup.
    final List<Map<String, dynamic>> dnsRules =
        proxyMode == ProxyMode.rule && _hasLocalRules
        ? [
            // CN-domain queries stay on CN DNS (avoids proxy DNS for local sites).
            {'rule_set': 'geosite-cn', 'server': 'cn-dns'},
          ]
        : [];

    // ── Inbounds ─────────────────────────────────────────────────────────────
    final inbounds = <Map<String, dynamic>>[
      {
        'type': 'mixed',
        'tag': 'mixed-in',
        'listen': '127.0.0.1',
        'listen_port': port,
      },
      if (networkMode == NetworkMode.tun)
        {
          'type': 'tun',
          'tag': 'tun-in',
          'address': ['172.19.0.1/30', 'fdfe:dcba:9876::1/126'],
          'mtu': 1500,
          'auto_route': true,
          'strict_route': true,
          'stack': 'mixed',
          // sniff moved to route rule action (deprecated on inbound in v1.11,
          // removed in v1.13).
          if (proxyMode == ProxyMode.rule && _hasLocalRules)
            'route_exclude_address_set': ['geoip-cn'],
        },
    ];

    // ── Assemble ─────────────────────────────────────────────────────────────
    return {
      'log': {'level': 'warn', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          'secret': apiSecret,
          'default_mode': 'rule',
        },
        // Cache DNS results and rule-set lookups across restarts.
        'cache_file': {'enabled': true},
      },
      'dns': {
        'servers': [
          remoteDnsServer,
          {
            // DoH over the raw IP: encrypted on port 443, so transparent-proxy
            // gateways (e.g. router OpenClash) can't hijack it and return
            // fake-ip for node server domains — plain UDP 53 gets intercepted.
            // No detour: sing-box routes via ip_cidr ['223.5.5.5']→direct rule.
            // detour:'direct' is rejected by sing-box (DNS server limitation).
            'tag': 'cn-dns',
            'type': 'https',
            'server': '223.5.5.5',
          },
        ],
        'rules': dnsRules,
        'final': 'remote-dns',
        'independent_cache': true,
      },
      'inbounds': inbounds,
      'outbounds': [
        // Selector — the single exit; switched at runtime via Clash API.
        {
          'type': 'selector',
          'tag': selectorTag,
          'outbounds': [autoSelectTag, ...tags],
          'default': defaultOutbound,
        },
        // Auto-select: tests all nodes every 10 min and picks the fastest.
        {
          'type': 'urltest',
          'tag': autoSelectTag,
          'outbounds': tags,
          'url': delayTestUrl,
          'interval': '10m',
          'tolerance': 50,
        },
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block', 'tag': 'block'},
      ],
      'route': {
        'rules': [
          // sniff MUST be first: it sets protocol metadata (e.g. marks a UDP
          // port-53 packet as "dns") so that the hijack-dns rule below can match.
          // Without sniff running first, protocol: dns never matches and DNS
          // queries fall through to the ip_cidr private rule → direct → lost.
          if (networkMode == NetworkMode.tun)
            {
              'inbound': ['tun-in'],
              'action': 'sniff',
            },
          // hijack-dns intercepts ALL DNS now that sniff has set the metadata.
          {'protocol': 'dns', 'action': 'hijack-dns'},
          // CN DoH stays direct so it can bootstrap proxy server domains.
          // remote-dns uses detour: PROXY for public DoH endpoints.
          {
            'ip_cidr': ['223.5.5.5'],
            'outbound': 'direct',
          },
          ...routeRules,
        ],
        if (ruleSets.isNotEmpty) 'rule_set': ruleSets,
        'final': routeFinal,
        'auto_detect_interface': true,
        'default_domain_resolver': 'cn-dns',
      },
    };
  }

  // ── Rule sets (rule mode only) ─────────────────────────────────────────────

  static List<Map<String, dynamic>> _ruleSets() {
    if (_hasLocalRules) {
      // Production: use bundled files next to the exe.
      final dir = _rulesDir;
      final sep = Platform.pathSeparator;
      return [
        {
          'tag': 'geosite-cn',
          'type': 'local',
          'format': 'binary',
          'path': '$dir${sep}geosite-cn.srs',
        },
        {
          'tag': 'geoip-cn',
          'type': 'local',
          'format': 'binary',
          'path': '$dir${sep}geoip-cn.srs',
        },
        {
          'tag': 'geosite-ads',
          'type': 'local',
          'format': 'binary',
          'path': '$dir${sep}geosite-category-ads-all.srs',
        },
      ];
    }
    // No local rules — rule-sets disabled, routing falls back to global (all via PROXY).
    return [];
  }

  // ── Tag helpers ────────────────────────────────────────────────────────────

  /// Stable sing-box outbound tag for a node. Used as Clash API proxy key.
  static String nodeTagFor(NodeModel node) => _nodeTag(node);

  static String _nodeTag(NodeModel n) => 'node-${n.id}';

  // ── File I/O ───────────────────────────────────────────────────────────────

  static String encodeConfig(Map<String, dynamic> config) =>
      const JsonEncoder.withIndent('  ').convert(config);

  static Future<String> writeConfig(Map<String, dynamic> config) async {
    final dir = Directory(appDataDir());
    await dir.create(recursive: true);
    final file = File('${dir.path}\\core.json');
    await file.writeAsString(encodeConfig(config));
    return file.path;
  }
}

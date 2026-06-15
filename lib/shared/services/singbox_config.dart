import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import 'outbound_parser.dart';

/// Generates sing-box JSON configs from parsed node lists.
///
/// Architecture:
/// - All nodes are written as outbounds with unique tags.
/// - A `urltest` outbound (自动选择) tests real proxy latency every 10 min.
/// - A `selector` outbound (PROXY) lets the user pick a node or auto-select.
/// - Clash-compatible REST API enables runtime node switching without restart.
/// - Rule mode uses remote rule_set files (OSS) for CN bypass + ad blocking.
abstract final class SingboxConfig {
  static const int defaultPort    = 7890;
  static const int defaultApiPort = 9090;

  // Rule set files are bundled next to the exe under rules\ in production.
  // During development they won't exist — _ruleSets() falls back to OSS.
  static String get _rulesDir {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\rules';
  }

  static bool get _hasLocalRules =>
      File('$_rulesDir\\geosite-cn.srs').existsSync();

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
    int port        = defaultPort,
    int apiPort     = defaultApiPort,
    ProxyMode proxyMode       = ProxyMode.rule,
    String dnsMode            = '系统 DNS',
    NetworkMode networkMode   = NetworkMode.system,
  }) {
    final outbounds = <Map<String, dynamic>>[];
    final tags      = <String>[];

    for (final n in nodes) {
      if (n.rawUri.isEmpty) continue;
      final ob = OutboundParser.parse(n.rawUri, tag: _nodeTag(n));
      if (ob == null) continue;
      outbounds.add(ob);
      tags.add(_nodeTag(n));
    }

    if (tags.isEmpty) return null;

    // Determine the active outbound for the selector's default.
    // Empty / unknown selectedTag → start with auto-select.
    final defaultOutbound =
        tags.contains(selectedTag) ? selectedTag : '自动选择';

    // ── Route & rule_set ────────────────────────────────────────────────────
    final String routeFinal;
    final List<Map<String, dynamic>> routeRules;
    final List<Map<String, dynamic>> ruleSets;

    switch (proxyMode) {
      case ProxyMode.global:
        routeFinal = 'PROXY';
        routeRules = [
          if (networkMode == NetworkMode.tun)
            {'inbound': ['tun-in'], 'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ];
        ruleSets = [];

      case ProxyMode.direct:
        routeFinal = 'direct';
        routeRules = [
          if (networkMode == NetworkMode.tun)
            {'inbound': ['tun-in'], 'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
        ];
        ruleSets = [];

      case ProxyMode.rule:
        routeFinal = 'PROXY';
        routeRules = [
          if (networkMode == NetworkMode.tun)
            {'inbound': ['tun-in'], 'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
          if (_hasLocalRules) ...[
            {'rule_set': 'geosite-ads', 'outbound': 'block'},
            {'rule_set': ['geosite-cn', 'geoip-cn'], 'outbound': 'direct'},
          ],
          {'ip_is_private': true, 'outbound': 'direct'},
        ];
        ruleSets = _ruleSets();
    }


    // ── DNS servers ─────────────────────────────────────────────────────────
    // cn-dns: always present; used for CN domains and routing-engine queries.
    // remote-dns: foreign / encrypted resolver (choice depends on dnsMode).
    final Map<String, dynamic> remoteDnsServer;
    final String dohServer;
    switch (dnsMode) {
      case 'Google':
        remoteDnsServer = {'tag': 'remote-dns', 'type': 'https', 'server': '8.8.8.8'};
        dohServer = '8.8.8.8';
      default: // '系统 DNS' and 'Cloudflare' both use Cloudflare DoH
        remoteDnsServer = {'tag': 'remote-dns', 'type': 'https', 'server': '1.1.1.1'};
        dohServer = '1.1.1.1';
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
          'address': ['172.19.0.1/30'],
          'mtu': 9000,
          'auto_route': true,
          'strict_route': true,
          'stack': 'system',
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
          'tag': 'PROXY',
          'outbounds': ['自动选择', ...tags],
          'default': defaultOutbound,
        },
        // Auto-select: tests all nodes every 10 min and picks the fastest.
        {
          'type': 'urltest',
          'tag': '自动选择',
          'outbounds': tags,
          'url': 'https://www.gstatic.com/generate_204',
          'interval': '10m',
          'tolerance': 50,
        },
        ...outbounds,
        {'type': 'direct', 'tag': 'direct'},
        {'type': 'block',  'tag': 'block'},
      ],
      'route': {
        // DoH server IPs must go direct to avoid circular DNS → PROXY → DNS.
        'rules': [
          {'ip_cidr': [dohServer, '223.5.5.5'], 'outbound': 'direct'},
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
      return [
        {'tag': 'geosite-cn',  'type': 'local', 'format': 'binary',
         'path': '$dir\\geosite-cn.srs'},
        {'tag': 'geoip-cn',    'type': 'local', 'format': 'binary',
         'path': '$dir\\geoip-cn.srs'},
        {'tag': 'geosite-ads', 'type': 'local', 'format': 'binary',
         'path': '$dir\\geosite-category-ads-all.srs'},
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
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final dir = Directory('$base\\Litchi');
    await dir.create(recursive: true);
    final file = File('${dir.path}\\core.json');
    await file.writeAsString(encodeConfig(config));
    return file.path;
  }
}

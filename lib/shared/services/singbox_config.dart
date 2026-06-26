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
/// - Rule mode uses bundled local rule_set files when available; if they are
///   absent in a dev/custom package, routing falls back to the default proxy path
///   instead of blocking the connection.
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
    final sep = Platform.pathSeparator;
    final base = Platform.isWindows
        ? (Platform.environment['LOCALAPPDATA'] ??
              Platform.environment['APPDATA'] ??
              Directory.systemTemp.path)
        : (Platform.environment['HOME'] != null
              ? '${Platform.environment['HOME']}/Library/Application Support'
              : Directory.systemTemp.path);
    return '$base${sep}Litchi';
  }

  // Rule set files are bundled next to the exe under rules\ in production.
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
    if (missing.isEmpty) return const RuleSetStatus(RuleSetState.normal);
    return RuleSetStatus(
      proxyMode == ProxyMode.rule ? RuleSetState.degraded : RuleSetState.missing,
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

    final defaultOutbound = tags.contains(selectedTag)
        ? selectedTag
        : autoSelectTag;

    final String routeFinal;
    final List<Map<String, dynamic>> routeRules;
    final List<Map<String, dynamic>> ruleSets;

    switch (proxyMode) {
      case ProxyMode.global:
        routeFinal = selectorTag;
        routeRules = [
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

    final Map<String, dynamic> remoteDnsServer;
    switch (dnsMode) {
      case 'Google':
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'https',
          'server': '8.8.8.8',
          'detour': autoSelectTag,
        };
      default:
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'https',
          'server': '1.1.1.1',
          'detour': autoSelectTag,
        };
    }

    // Must mirror the _hasLocalRules guard on route rules — referencing a
    // rule_set that isn't defined makes sing-box exit with FATAL at startup.
    final List<Map<String, dynamic>> dnsRules =
        proxyMode == ProxyMode.rule && _hasLocalRules
        ? [
            {'rule_set': 'geosite-cn', 'server': 'cn-dns'},
          ]
        : [];

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
          if (proxyMode == ProxyMode.rule && _hasLocalRules)
            'route_exclude_address_set': ['geoip-cn'],
        },
    ];

    return {
      'log': {'level': 'warn', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          'secret': apiSecret,
          'default_mode': proxyMode.clashValue,
        },
        'cache_file': {'enabled': true},
      },
      'dns': {
        'servers': [
          remoteDnsServer,
          {
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
        {
          'type': 'selector',
          'tag': selectorTag,
          'outbounds': [autoSelectTag, ...tags],
          'default': defaultOutbound,
        },
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
          if (networkMode == NetworkMode.tun)
            {
              'inbound': ['tun-in'],
              'action': 'sniff',
            },
          {'protocol': 'dns', 'action': 'hijack-dns'},
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

  static List<Map<String, dynamic>> _ruleSets() {
    if (!_hasLocalRules) return [];
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

  /// Stable sing-box outbound tag for a node. Used as Clash API proxy key.
  static String nodeTagFor(NodeModel node) => _nodeTag(node);

  static String _nodeTag(NodeModel n) => 'node-${n.id}';

  static String encodeConfig(Map<String, dynamic> config) =>
      const JsonEncoder.withIndent('  ').convert(config);

  static Future<String> writeConfig(Map<String, dynamic> config) async {
    final dir = Directory(appDataDir());
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}core.json');
    await file.writeAsString(encodeConfig(config));
    return file.path;
  }
}

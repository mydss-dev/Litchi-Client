import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import 'outbound_parser.dart';

/// Generates sing-box JSON configs from parsed node lists.
///
/// Architecture:
/// - All nodes are written as outbounds with unique tags.
/// - A `selector` outbound named `PROXY` acts as the active exit.
/// - Clash-compatible REST API is enabled so the active node can be
///   switched at runtime via HTTP — no process restart required.
abstract final class SingboxConfig {
  static const int defaultPort = 7890;
  static const int defaultApiPort = 9090;

  /// Random secret generated once per process — required by Clash API.
  static final String apiSecret = _generateSecret();
  static String _generateSecret() {
    final rng = Random.secure();
    return List.generate(16, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Build a complete multi-node config.
  ///
  /// [nodes]       — all available nodes (skips any with empty rawUri).
  /// [selectedTag] — the node tag that should be active on first start.
  /// [port]        — mixed inbound port (HTTP + SOCKS5).
  /// [apiPort]     — Clash-compatible REST API port for runtime switching.
  /// [proxyMode]   — '规则模式' | '全局模式' | '直连模式'
  /// [dnsMode]     — '系统 DNS' | 'Cloudflare' | 'Google'
  ///
  /// Returns null only when [nodes] is empty or all URIs are unparseable.
  static Map<String, dynamic>? buildFullConfig(
    List<NodeModel> nodes, {
    required String selectedTag,
    int port = defaultPort,
    int apiPort = defaultApiPort,
    String proxyMode = '规则模式',
    String dnsMode = '系统 DNS',
  }) {
    final outbounds = <Map<String, dynamic>>[];
    final tags = <String>[];

    for (final n in nodes) {
      if (n.rawUri.isEmpty) continue;
      final ob = OutboundParser.parse(n.rawUri, tag: _nodeTag(n));
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
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ];
      case '直连模式':
        routeFinal = 'direct';
        routeRules = [
          {'protocol': 'dns', 'action': 'hijack-dns'},
        ];
      case '规则模式':
      case '智能模式': // Backward compatibility with older stored settings.
      default:
        routeFinal = 'PROXY';
        routeRules = [
          {'protocol': 'dns', 'action': 'hijack-dns'},
          {'ip_is_private': true, 'outbound': 'direct'},
        ];
    }

    // Remote DNS config depends on user's DNS mode setting.
    // sing-box 1.14+ requires new format: "type" + "server" instead of "address" URL.
    final Map<String, dynamic> remoteDnsServer;
    switch (dnsMode) {
      case 'Cloudflare':
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'tls',
          'server': '1.1.1.1',
          'detour': 'PROXY',
        };
      case 'Google':
        remoteDnsServer = {
          'tag': 'remote-dns',
          'type': 'tls',
          'server': '8.8.8.8',
          'detour': 'PROXY',
        };
      default: // '系统 DNS'
        remoteDnsServer = {'tag': 'remote-dns', 'type': 'local'};
    }

    return {
      'log': {'level': 'warn', 'timestamp': true},
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          'secret': apiSecret,
        },
      },
      'dns': {
        'servers': [
          remoteDnsServer,
          {'tag': 'local-dns', 'type': 'udp', 'server': '223.5.5.5'},
        ],
        'rules': [],
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
      ],
      'route': {
        'rules': routeRules,
        'final': routeFinal,
        'auto_detect_interface': true,
        'default_domain_resolver': 'local-dns',
      },
    };
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────

  /// Derive a stable sing-box outbound tag from a node.
  /// Tags must be non-empty and are used as REST API keys.
  static String nodeTagFor(NodeModel node) => _nodeTag(node);

  static String _nodeTag(NodeModel n) => 'node-${n.id}';

  // ── File I/O ──────────────────────────────────────────────────────────────

  static Future<String> writeConfig(Map<String, dynamic> config) async {
    // Write to private app data dir, not the shared system temp dir.
    final base = Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['APPDATA'] ??
        Directory.systemTemp.path;
    final dir = Directory('$base\\Litchi');
    await dir.create(recursive: true);
    final file = File('${dir.path}\\core.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
    return file.path;
  }
}

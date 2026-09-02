import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../config/app_identity.dart';
import '../models/app_models.dart';
import 'app_paths.dart';
import 'rule_set_assets.dart';

/// Builds the JSON configuration consumed by the embedded sing-box core.
///
/// Native proxy outbounds come from the panel. This class owns application
/// policy (inbounds, selectors, DNS and routing).
abstract final class SingBoxConfig {
  static const String coreVersion = '1.13.13';
  static const String subscriptionUserAgent = 'sing-box $coreVersion';

  /// Proxy outbound types the pinned sing-box core can actually load.
  ///
  /// Nodes whose type is missing here are skipped individually instead of
  /// failing the whole config — one unsupported node must never take down
  /// every connection.
  static const Set<String> coreSupportedOutboundTypes = {
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
    'naive',
    'shadowtls',
    'tor',
    'tailscale',
  };
  static const int defaultPort = 7890;
  static const int defaultApiPort = 9090;
  static const String selectorTag = 'proxy';
  static const String autoSelectTag = 'auto';
  static const String directTag = 'direct';
  static const String blockTag = 'block';
  static const String delayTestUrl = 'https://www.gstatic.com/generate_204';

  static String appDataDir() => AppPaths.dataDirectory;

  static String nodeTagFor(NodeModel node) => 'node-${node.id}';

  static Map<String, dynamic>? buildFullConfig(
    List<NodeModel> nodes, {
    required String selectedTag,
    int port = defaultPort,
    int apiPort = defaultApiPort,
    String apiSecret = '',
    ProxyMode proxyMode = ProxyMode.rule,
    DnsMode dnsMode = DnsMode.system,
    NetworkMode networkMode = NetworkMode.system,
    bool allowInsecure = false,
  }) {
    final nodeOutbounds = <Map<String, dynamic>>[];
    final nodeTags = <String>[];

    for (final node in nodes) {
      final tag = nodeTagFor(node);
      final source = node.rawOutbound;
      if (source == null || source['_litchi_format'] != 'sing-box') continue;
      final outbound = _nativeOutbound(
        source,
        tag: tag,
        allowInsecure: allowInsecure,
      );
      if (outbound == null || !_isUsableOutbound(outbound)) continue;
      nodeOutbounds.add(_deepMap(outbound));
      nodeTags.add(tag);
    }
    if (nodeTags.isEmpty) return null;

    final selected = nodeTags.contains(selectedTag)
        ? selectedTag
        : nodeTags.first;
    return {
      'log': {'level': 'warn', 'timestamp': true},
      'dns': _dnsConfig(dnsMode),
      'inbounds': [
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
            'interface_name': Platform.isMacOS
                ? 'utun'
                : AppIdentity.tunInterfaceAlias,
            'address': ['172.19.0.1/30'],
            // Windows cloud/remote desktops are sensitive to jumbo MTUs and
            // aggressive route locking. Keep the adapter conventional there;
            // physical/macOS/Linux clients retain the existing larger MTU.
            'mtu': Platform.isWindows ? 1500 : 9000,
            'auto_route': true,
            'strict_route': !Platform.isWindows,
            'stack': 'system',
          },
      ],
      'outbounds': [
        ...nodeOutbounds,
        {
          'type': 'urltest',
          'tag': autoSelectTag,
          'outbounds': nodeTags,
          'url': delayTestUrl,
          'interval': '10m',
          'tolerance': 50,
        },
        {
          'type': 'selector',
          'tag': selectorTag,
          'outbounds': [autoSelectTag, ...nodeTags],
          'default': selected,
        },
        {'type': 'direct', 'tag': directTag},
        {'type': 'block', 'tag': blockTag},
      ],
      'route': {
        'auto_detect_interface': true,
        // Node servers are usually domains. Route their resolution through the
        // local/system DNS server instead of the (possibly proxied) final
        // resolver, otherwise a remote DoH final can deadlock bootstrapping.
        // Required since sing-box 1.14 whenever more than one DNS server is
        // configured.
        'default_domain_resolver': {
          'server': 'dns-local',
          'strategy': 'ipv4_only',
        },
        // Mainland-China direct rules: geosite-cn (domain) + geoip-cn (IP).
        // Shipped as embedded assets and extracted to the core's working
        // directory at startup (see RuleSetAssets.ensureProvisioned), so
        // startup never depends on a reachable CDN.
        'rule_set': [
          {
            'type': 'local',
            'tag': 'geosite-cn',
            'format': 'binary',
            'path': 'rule_sets/geosite-cn.srs',
          },
          {
            'type': 'local',
            'tag': 'geoip-cn',
            'format': 'binary',
            'path': 'rule_sets/geoip-cn.srs',
          },
        ],
        'rules': [
          {'clash_mode': 'direct', 'outbound': directTag},
          {'clash_mode': 'global', 'outbound': selectorTag},
          {
            'rule_set': ['geosite-cn', 'geoip-cn'],
            'outbound': directTag,
          },
          {'ip_is_private': true, 'outbound': directTag},
        ],
        'final': selectorTag,
      },
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          if (apiSecret.isNotEmpty) 'secret': apiSecret,
          'default_mode': proxyMode.storageKey,
        },
        'cache_file': {
          'enabled': true,
          // Relative to the native core's working directory (AppPaths.dataDirectory),
          // which is passed to litchi_core_start. An absolute path here would be
          // re-joined onto that base by sing-box's filemanager and double up.
          'path': 'sing-box.db',
          'store_fakeip': false,
        },
      },
      // Application metadata. Removed by [encodeConfig].
      'litchi-selected-outbound': selected,
    };
  }

  static Map<String, dynamic>? _nativeOutbound(
    Map<String, dynamic> source, {
    required String tag,
    required bool allowInsecure,
  }) {
    final outbound = _deepMap(source)..remove('_litchi_format');
    final type = '${outbound['type'] ?? ''}'.trim();
    final server = '${outbound['server'] ?? ''}'.trim();
    if (type.isEmpty || server.isEmpty || !_hasPort(outbound)) return null;
    outbound['tag'] = tag;
    // The panel profile may attach a domain_resolver referencing its own DNS
    // tag (e.g. `local`), which does not exist in the client config. The
    // client resolves node domains via route.default_domain_resolver (system
    // DNS bootstrap) and everything else through the DNS module final, so a
    // per-outbound resolver is both unnecessary and would fail to load.
    outbound.remove('domain_resolver');
    if (!allowInsecure && outbound['tls'] is Map) {
      (outbound['tls'] as Map).remove('insecure');
    }
    return outbound;
  }

  static Map<String, dynamic> _dnsConfig(DnsMode mode) {
    final servers = switch (mode) {
      DnsMode.google => <Map<String, dynamic>>[
        {
          'type': 'https',
          'tag': 'dns-remote',
          'server': 'dns.google',
          'server_port': 443,
          'path': '/dns-query',
          'tls': {'enabled': true, 'server_name': 'dns.google'},
          // The remote DoH endpoints are unreachable with direct connections
          // from mainland China. Route their traffic through the proxy, or
          // selecting this mode means no connectivity at all.
          'detour': selectorTag,
        },
        {'type': 'local', 'tag': 'dns-local'},
      ],
      DnsMode.cloudflare => <Map<String, dynamic>>[
        {
          'type': 'https',
          'tag': 'dns-remote',
          'server': '1.1.1.1',
          'server_port': 443,
          'path': '/dns-query',
          'tls': {'enabled': true, 'server_name': 'cloudflare-dns.com'},
          'detour': selectorTag,
        },
        {'type': 'local', 'tag': 'dns-local'},
      ],
      _ => <Map<String, dynamic>>[
        {'type': 'local', 'tag': 'dns-local'},
      ],
    };
    return {
      'servers': servers,
      'final': servers.first['tag'],
      'strategy': 'ipv4_only',
      // Mainland domains resolve through the local DNS; everything else uses
      // the mode's final resolver.
      'rules': [
        {
          'rule_set': ['geosite-cn'],
          'server': 'dns-local',
        },
      ],
    };
  }

  static bool _isUsableOutbound(Map<String, dynamic> outbound) {
    final type = '${outbound['type'] ?? ''}';
    final tag = '${outbound['tag'] ?? ''}';
    final server = '${outbound['server'] ?? ''}';
    return type.isNotEmpty &&
        coreSupportedOutboundTypes.contains(type) &&
        tag.isNotEmpty &&
        server.isNotEmpty &&
        _hasPort(outbound);
  }

  static bool _hasPort(Map<String, dynamic> outbound) {
    final port = outbound['server_port'];
    if (port is num && port > 0) return true;
    final ranges = outbound['server_ports'];
    return ranges is List && ranges.isNotEmpty;
  }

  static String encodeConfig(Map<String, dynamic> config) {
    final clean = _deepMap(config)..remove('litchi-selected-outbound');
    return const JsonEncoder.withIndent('  ').convert(clean);
  }

  static Future<String> writeConfig(Map<String, dynamic> config) async {
    await RuleSetAssets.ensureProvisioned();
    final directory = Directory(appDataDir());
    await directory.create(recursive: true);
    await cleanupStaleConfigFiles();
    final nonce = Random.secure().nextInt(1 << 32).toRadixString(16);
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'litchi_singbox_${DateTime.now().microsecondsSinceEpoch}_$nonce.json',
    );
    await file.writeAsString(encodeConfig(config), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {
        // Best effort: restrictive permissions are not available everywhere.
      }
    }
    return file.path;
  }

  static Future<void> cleanupStaleConfigFiles() async {
    final directory = Directory(appDataDir());
    if (!await directory.exists()) return;
    try {
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith('litchi_singbox_') || !name.endsWith('.json')) {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {
          // A running core may still own the file.
        }
      }
    } catch (_) {
      // Startup cleanup must never prevent a connection attempt.
    }
  }

  static Map<String, dynamic> _deepMap(Map source) => {
    for (final entry in source.entries)
      entry.key.toString(): _deepValue(entry.value),
  };

  static Object? _deepValue(Object? value) {
    if (value is Map) return _deepMap(value);
    if (value is List) return value.map(_deepValue).toList();
    return value;
  }
}

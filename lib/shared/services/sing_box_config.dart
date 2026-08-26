import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../config/app_identity.dart';
import '../models/app_models.dart';
import 'app_paths.dart';

/// Builds the JSON configuration consumed by the embedded sing-box core.
///
/// Native proxy outbounds come from the panel. This class owns application
/// policy (inbounds, selectors, DNS and routing).
abstract final class SingBoxConfig {
  static const String coreVersion = '1.13.13';
  static const String subscriptionUserAgent = 'sing-box $coreVersion';
  static const int defaultPort = 7890;
  static const int defaultApiPort = 9090;
  static const String selectorTag = 'proxy';
  static const String autoSelectTag = 'auto';
  static const String directTag = 'direct';
  static const String blockTag = 'block';
  static const String delayTestUrl =
      'https://www.gstatic.com/generate_204';

  static String appDataDir() => AppPaths.dataDirectory;

  static String nodeTagFor(NodeModel node) => 'node-${node.id}';

  static Map<String, dynamic>? buildFullConfig(
    List<NodeModel> nodes, {
    required String selectedTag,
    int port = defaultPort,
    int apiPort = defaultApiPort,
    ProxyMode proxyMode = ProxyMode.rule,
    String dnsMode = '系统 DNS',
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
            'mtu': 9000,
            'auto_route': true,
            'strict_route': true,
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
        'rules': [
          {
            'clash_mode': 'direct',
            'outbound': directTag,
          },
          {
            'clash_mode': 'global',
            'outbound': selectorTag,
          },
          {
            'ip_is_private': true,
            'outbound': directTag,
          },
        ],
        'final': selectorTag,
      },
      'experimental': {
        'clash_api': {
          'external_controller': '127.0.0.1:$apiPort',
          'default_mode': proxyMode.storageKey,
        },
        'cache_file': {
          'enabled': true,
          'path': '${appDataDir()}${Platform.pathSeparator}sing-box.db',
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
    // The panel profile refers to its own DNS tag (`local`). The client owns
    // DNS configuration, so imported nodes must use the client's final DNS.
    outbound.remove('domain_resolver');
    if (!allowInsecure && outbound['tls'] is Map) {
      (outbound['tls'] as Map).remove('insecure');
    }
    return outbound;
  }

  static Map<String, dynamic> _dnsConfig(String mode) {
    final servers = switch (mode) {
      'Google' => <Map<String, dynamic>>[
        {
          'type': 'https',
          'tag': 'dns-remote',
          'server': 'dns.google',
          'server_port': 443,
          'path': '/dns-query',
          'tls': {'enabled': true, 'server_name': 'dns.google'},
        },
        {'type': 'local', 'tag': 'dns-local'},
      ],
      'Cloudflare' => <Map<String, dynamic>>[
        {
          'type': 'https',
          'tag': 'dns-remote',
          'server': '1.1.1.1',
          'server_port': 443,
          'path': '/dns-query',
          'tls': {'enabled': true, 'server_name': 'cloudflare-dns.com'},
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
    };
  }

  static bool _isUsableOutbound(Map<String, dynamic> outbound) {
    final type = '${outbound['type'] ?? ''}';
    final tag = '${outbound['tag'] ?? ''}';
    final server = '${outbound['server'] ?? ''}';
    return type.isNotEmpty &&
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

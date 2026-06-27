import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/app_models.dart';
import 'outbound_parser.dart';

/// Generates a native mihomo configuration.
///
/// Clash subscription entries are preserved as-is. URI subscriptions are
/// normalized by [OutboundParser] and converted once to mihomo proxy fields.
abstract final class MihomoConfig {
  static const int defaultPort = 7890;
  static const int defaultApiPort = 9090;
  static const String selectorTag = 'PROXY';
  static const String autoSelectTag = 'AUTO';
  static const String globalTag = 'GLOBAL';
  static const String delayTestUrl = 'https://www.gstatic.com/generate_204';

  static final String apiSecret = _generateSecret();

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
    final proxies = <Map<String, dynamic>>[];
    final names = <String>[];

    for (final node in nodes) {
      final name = nodeTagFor(node);
      final proxy = _proxyFor(node, name: name, allowInsecure: allowInsecure);
      if (proxy == null) continue;
      proxies.add(proxy);
      names.add(name);
    }
    if (names.isEmpty) return null;

    final selected = names.contains(selectedTag) ? selectedTag : autoSelectTag;
    final rules = <String>[
      'IP-CIDR,127.0.0.0/8,DIRECT,no-resolve',
      'IP-CIDR,10.0.0.0/8,DIRECT,no-resolve',
      'IP-CIDR,172.16.0.0/12,DIRECT,no-resolve',
      'IP-CIDR,192.168.0.0/16,DIRECT,no-resolve',
      'IP-CIDR,169.254.0.0/16,DIRECT,no-resolve',
      'IP-CIDR,100.64.0.0/10,DIRECT,no-resolve',
      'IP-CIDR6,::1/128,DIRECT,no-resolve',
      'IP-CIDR6,fc00::/7,DIRECT,no-resolve',
      'IP-CIDR6,fe80::/10,DIRECT,no-resolve',
      'MATCH,$selectorTag',
    ];

    final nameserver = switch (dnsMode) {
      'Google' => 'https://dns.google/dns-query',
      'Cloudflare' => 'https://1.1.1.1/dns-query',
      _ => 'system',
    };

    return {
      'mixed-port': port,
      'allow-lan': false,
      'bind-address': '127.0.0.1',
      'mode': proxyMode.clashValue,
      'log-level': 'warning',
      'ipv6': true,
      'unified-delay': true,
      'tcp-concurrent': true,
      'external-controller': '127.0.0.1:$apiPort',
      'secret': apiSecret,
      'profile': {'store-selected': false, 'store-fake-ip': false},
      'dns': {
        'enable': true,
        'ipv6': true,
        'enhanced-mode': 'fake-ip',
        'fake-ip-range': '198.18.0.1/16',
        'nameserver': [nameserver],
        'fallback': [
          'https://1.1.1.1/dns-query',
          'https://dns.google/dns-query',
        ],
      },
      // Android supplies a VpnService-owned file descriptor to the embedded
      // core. The ordinary config TUN is therefore only enabled on desktop.
      'tun': {
        'enable': networkMode == NetworkMode.tun,
        'stack': 'mixed',
        'device': 'Litchi',
        'dns-hijack': ['any:53'],
        'auto-route': true,
        'strict-route': true,
        'auto-detect-interface': true,
      },
      'proxies': proxies,
      'proxy-groups': [
        {
          'name': selectorTag,
          'type': 'select',
          'proxies': [autoSelectTag, ...names],
        },
        {
          'name': autoSelectTag,
          'type': 'url-test',
          'proxies': names,
          'url': delayTestUrl,
          'interval': 600,
          'tolerance': 50,
          'lazy': true,
        },
      ],
      'rules': rules,
      'litchi-selected-proxy': selected,
    };
  }

  static Map<String, dynamic>? _proxyFor(
    NodeModel node, {
    required String name,
    required bool allowInsecure,
  }) {
    if (node.rawOutbound != null) {
      final proxy = _deepMap(node.rawOutbound!);
      final type = '${proxy['type'] ?? ''}'.toLowerCase();
      if (!_supportedTypes.contains(type)) return null;
      proxy['name'] = name;
      if (!allowInsecure) proxy.remove('skip-cert-verify');
      return proxy;
    }

    final outbound = OutboundParser.parse(
      node.rawUri,
      tag: name,
      allowInsecure: allowInsecure,
    );
    return outbound == null ? null : _normalizedToMihomo(outbound);
  }

  static const _supportedTypes = {
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

  static Map<String, dynamic> _normalizedToMihomo(Map<String, dynamic> source) {
    final type = source['type'] == 'shadowsocks' ? 'ss' : source['type'];
    final out = <String, dynamic>{
      'name': source['tag'],
      'type': type,
      'server': source['server'],
      'port': source['server_port'],
    };

    void copy(String from, [String? to]) {
      final value = source[from];
      if (value != null && value != '') out[to ?? from] = value;
    }

    copy('uuid');
    copy('password');
    copy('method', 'cipher');
    copy('security', 'cipher');
    copy('alter_id', 'alterId');
    copy('flow');
    copy('up');
    copy('down');
    copy('auth_str', 'auth-str');
    copy('obfs');
    copy('network');
    copy('congestion_control', 'congestion-controller');
    copy('udp_relay_mode', 'udp-relay-mode');
    copy('idle_session_check_interval', 'idle-session-check-interval');
    copy('idle_session_timeout', 'idle-session-timeout');
    copy('min_idle_session', 'min-idle-session');

    final tls = source['tls'];
    if (tls is Map) {
      out['tls'] = tls['enabled'] == true;
      final serverName = tls['server_name'];
      if (serverName != null && '$serverName'.isNotEmpty) {
        out['servername'] = serverName;
        out['sni'] = serverName;
      }
      if (tls['insecure'] == true) out['skip-cert-verify'] = true;
      if (tls['alpn'] != null) out['alpn'] = tls['alpn'];
      final utls = tls['utls'];
      if (utls is Map && utls['fingerprint'] != null) {
        out['client-fingerprint'] = utls['fingerprint'];
      }
      final reality = tls['reality'];
      if (reality is Map && reality['enabled'] == true) {
        out['reality-opts'] = {
          'public-key': reality['public_key'],
          if (reality['short_id'] != null) 'short-id': reality['short_id'],
          if (reality['spider_x'] != null) 'spider-x': reality['spider_x'],
        };
      }
    }

    final transport = source['transport'];
    if (transport is Map) {
      final network = '${transport['type'] ?? ''}';
      if (network == 'http') {
        out['network'] = 'h2';
        out['h2-opts'] = {
          if (transport['host'] != null) 'host': transport['host'],
          if (transport['path'] != null) 'path': transport['path'],
        };
      } else if (network == 'ws') {
        out['network'] = 'ws';
        out['ws-opts'] = {
          if (transport['path'] != null) 'path': transport['path'],
          if (transport['headers'] != null) 'headers': transport['headers'],
        };
      } else if (network == 'grpc') {
        out['network'] = 'grpc';
        out['grpc-opts'] = {
          if (transport['service_name'] != null)
            'grpc-service-name': transport['service_name'],
        };
      }
    }
    return out;
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

  static String nodeTagFor(NodeModel node) => 'node-${node.id}';

  static String encodeConfig(Map<String, dynamic> config) {
    final clean = Map<String, dynamic>.from(config);
    // This is application metadata used to restore the initial selector. It is
    // not part of the mihomo schema.
    clean.remove('litchi-selected-proxy');
    return const JsonEncoder.withIndent('  ').convert(clean);
  }

  /// Writes the full mihomo configuration to a one-time-use file and returns
  /// its path.  The filename embeds a wall-clock timestamp and a random nonce
  /// so no other process can predict it.  The file is deleted as soon as
  /// mihomo confirms readiness (see [CoreManager.start]).
  ///
  /// Stale files from a previous crash are cleaned up before writing.  On
  /// non-Windows platforms the file is `chmod 600` so only the owning user
  /// can read it.
  static Future<String> writeConfig(Map<String, dynamic> config) async {
    final dir = Directory(appDataDir());
    await dir.create(recursive: true);
    await cleanupStaleConfigFiles();

    final nonce = Random.secure().nextInt(1 << 32).toRadixString(16);
    final name = 'litchi_core_'
        '${DateTime.now().microsecondsSinceEpoch}_$nonce.yaml';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsString(encodeConfig(config), flush: true);
    if (!Platform.isWindows) {
      try {
        await Process.run('chmod', ['600', file.path]);
      } catch (_) {}
    }
    return file.path;
  }

  /// Removes any leftover `litchi_core_*.yaml` files from a previous crash.
  /// Called at app startup and again inside [writeConfig].
  static Future<void> cleanupStaleConfigFiles() async {
    try {
      final dir = Directory(appDataDir());
      if (!await dir.exists()) return;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (!name.startsWith('litchi_core_') || !name.endsWith('.yaml')) {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _generateSecret() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

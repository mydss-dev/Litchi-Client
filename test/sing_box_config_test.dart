import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/sing_box_config.dart';

void main() {
  const node = NodeModel(
    id: 'hk-1',
    name: 'Hong Kong',
    flag: '',
    latency: 0,
    rawOutbound: {
      'type': 'trojan',
      'tag': 'source',
      'server': 'example.com',
      'server_port': 443,
      'password': 'password',
      'tls': {'enabled': true, 'server_name': 'example.com'},
      '_litchi_format': 'sing-box',
    },
  );

  test('builds native sing-box JSON with a stable selector', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    );

    expect(config, isNotNull);
    final outbounds = (config!['outbounds'] as List).cast<Map>();
    expect(
      outbounds,
      contains(
        containsPair('tag', SingBoxConfig.nodeTagFor(node)),
      ),
    );
    expect(
      outbounds.firstWhere(
        (outbound) => outbound['tag'] == SingBoxConfig.selectorTag,
      )['default'],
      SingBoxConfig.nodeTagFor(node),
    );

    final encoded = jsonDecode(SingBoxConfig.encodeConfig(config));
    expect(encoded, isA<Map>());
    expect((encoded as Map).containsKey('litchi-selected-outbound'), isFalse);
  });

  test('uses Clash mode routing for dynamic direct mode', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
      proxyMode: ProxyMode.direct,
    )!;
    final route = config['route'] as Map;
    final rules = (route['rules'] as List).cast<Map>();
    expect(route['final'], SingBoxConfig.selectorTag);
    expect(
      rules,
      contains(
        allOf(
          containsPair('clash_mode', 'direct'),
          containsPair('outbound', SingBoxConfig.directTag),
        ),
      ),
    );
  });

  test('preserves native sing-box outbounds while assigning stable tags', () {
    const nativeNode = NodeModel(
      id: 'ss-1',
      name: 'SS',
      flag: '',
      latency: 0,
      rawOutbound: {
        'tag': 'SS',
        'type': 'shadowsocks',
        'server': 'ss.example.com',
        'server_port': 8443,
        'method': 'aes-128-gcm',
        'password': 'secret',
        '_litchi_format': 'sing-box',
      },
    );
    final config = SingBoxConfig.buildFullConfig(
      const [nativeNode],
      selectedTag: SingBoxConfig.nodeTagFor(nativeNode),
    )!;
    final outbound = (config['outbounds'] as List)
        .cast<Map>()
        .firstWhere((item) => item['tag'] == 'node-ss-1');

    expect(outbound['type'], 'shadowsocks');
    expect(outbound['server_port'], 8443);
    expect(outbound['method'], 'aes-128-gcm');
  });

  test('adds a TUN inbound only in TUN mode', () {
    final systemConfig = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    )!;
    final tunConfig = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
      networkMode: NetworkMode.tun,
    )!;

    expect((systemConfig['inbounds'] as List), hasLength(1));
    expect((tunConfig['inbounds'] as List), hasLength(2));
    expect(((tunConfig['inbounds'] as List)[1] as Map)['type'], 'tun');
  });

  test('writes the random secret into experimental.clash_api', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
      apiSecret: 's3cr3t-t0ken',
    )!;
    final clashApi = ((config['experimental'] as Map)['clash_api'] as Map);
    expect(clashApi['secret'], 's3cr3t-t0ken');
    expect(
      clashApi['external_controller'],
      '127.0.0.1:${SingBoxConfig.defaultApiPort}',
    );

    final noSecret = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    )!;
    final bareApi =
        ((noSecret['experimental'] as Map)['clash_api'] as Map);
    expect(bareApi.containsKey('secret'), isFalse);
  });

  test('bootstraps node domains through the local resolver', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    )!;
    final route = config['route'] as Map;
    expect(
      route['default_domain_resolver'],
      {'server': 'dns-local', 'strategy': 'ipv4_only'},
    );
  });

  test('routes mainland China domains and IPs directly', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    )!;
    final route = config['route'] as Map;
    final ruleSets = (route['rule_set'] as List).cast<Map>();
    expect(
      ruleSets.map((s) => s['tag']),
      containsAll(['geosite-cn', 'geoip-cn']),
    );
    // Rule sets are embedded assets, not remote downloads: startup must never
    // depend on a reachable CDN.
    for (final ruleSet in ruleSets) {
      expect(ruleSet['type'], 'local');
      expect(ruleSet['path'], isNotEmpty);
      expect(ruleSet.containsKey('url'), isFalse);
    }
    final rules = (route['rules'] as List).cast<Map>();
    expect(
      rules,
      contains(
        allOf(
          containsPair('rule_set', ['geosite-cn', 'geoip-cn']),
          containsPair('outbound', SingBoxConfig.directTag),
        ),
      ),
    );

    final dns = config['dns'] as Map;
    final dnsRules = (dns['rules'] as List).cast<Map>();
    expect(
      dnsRules,
      contains(
        allOf(
          containsPair('rule_set', ['geosite-cn']),
          containsPair('server', 'dns-local'),
        ),
      ),
    );
  });

  test('routes remote DoH through the proxy in Google/Cloudflare modes', () {
    for (final mode in [DnsMode.google, DnsMode.cloudflare]) {
      final config = SingBoxConfig.buildFullConfig(
        const [node],
        selectedTag: SingBoxConfig.nodeTagFor(node),
        dnsMode: mode,
      )!;
      final servers = ((config['dns'] as Map)['servers'] as List)
          .cast<Map>();
      final remote = servers.firstWhere(
        (s) => s['tag'] == 'dns-remote',
      );
      expect(remote['detour'], SingBoxConfig.selectorTag);
    }
  });

  test('skips node types the core cannot load instead of failing', () {
    // snell/mieru are not registered outbound types in the pinned core
    // (v1.13.13) — such a node must be dropped, never allowed to poison the
    // whole config.
    for (final unsupported in ['snell', 'mieru']) {
      final badNode = NodeModel(
        id: unsupported,
        name: unsupported,
        flag: '',
        latency: 0,
        rawOutbound: {
          'type': unsupported,
          'server': 'example.com',
          'server_port': 443,
          '_litchi_format': 'sing-box',
        },
      );
      final config = SingBoxConfig.buildFullConfig(
        [badNode],
        selectedTag: SingBoxConfig.nodeTagFor(badNode),
      );
      // No usable nodes remain → no config is produced at all.
      expect(config, isNull, reason: '$unsupported must be skipped');
    }
  });

  test('keeps usable nodes when a profile mixes supported and unsupported types',
      () {
    const snellNode = NodeModel(
      id: 'snell-1',
      name: 'Snell',
      flag: '',
      latency: 0,
      rawOutbound: {
        'type': 'snell',
        'server': 'snell.example.com',
        'server_port': 8443,
        'psk': 'secret',
        '_litchi_format': 'sing-box',
      },
    );
    final config = SingBoxConfig.buildFullConfig(
      const [node, snellNode],
      selectedTag: SingBoxConfig.nodeTagFor(node),
    );

    expect(config, isNotNull);
    final outbounds = (config!['outbounds'] as List).cast<Map>();
    final tags = outbounds.map((o) => o['tag']).toSet();
    expect(tags, contains('node-hk-1'));
    expect(tags, isNot(contains('node-snell-1')));
    // The selector must not reference the dropped node.
    final selector = outbounds.firstWhere(
      (outbound) => outbound['tag'] == SingBoxConfig.selectorTag,
    );
    expect(selector['outbounds'], isNot(contains('node-snell-1')));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/mihomo_config.dart';

void main() {
  test('restores a running Android controller secret safely', () {
    final original = MihomoConfig.apiSecret;
    addTearDown(() => MihomoConfig.restoreApiSecret(original));

    MihomoConfig.restoreApiSecret('restored-secret');
    expect(MihomoConfig.apiSecret, 'restored-secret');

    MihomoConfig.restoreApiSecret('');
    expect(MihomoConfig.apiSecret, 'restored-secret');
  });

  test('appDataDir is under a Litchi folder', () {
    expect(MihomoConfig.appDataDir(), contains('Litchi'));
  });

  test(
    'buildFullConfig produces a config for a parseable node in global mode',
    () {
      const node = NodeModel(
        id: 'n1',
        name: 'hk',
        flag: '',
        latency: 0,
        rawUri: 'trojan://password@example.com:443#hk',
      );
      final config = MihomoConfig.buildFullConfig(
        [node],
        selectedTag: MihomoConfig.nodeTagFor(node),
        proxyMode: ProxyMode.global,
      );
      expect(config, isNotNull);
      expect(config!['proxies'], isA<List>());
      expect(config['proxy-groups'], isA<List>());
    },
  );

  test('rule mode still builds when bundled rule files are absent', () {
    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#hk',
    );
    final config = MihomoConfig.buildFullConfig(
      [node],
      selectedTag: MihomoConfig.nodeTagFor(node),
      proxyMode: ProxyMode.rule,
    );

    expect(config, isNotNull);
    expect(
      (config!['dns'] as Map<String, dynamic>)['fake-ip-filter'],
      containsAll(<String>['localhost', '*.local', '*.lan']),
    );
    expect((config['dns'] as Map<String, dynamic>)['nameserver'], const [
      'system',
    ]);
    expect(
      (config['dns'] as Map<String, dynamic>).containsKey('fallback'),
      isFalse,
    );
    expect(config['rules'], isA<List>());
  });

  test('removes dangling dialer-proxy group references', () {
    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawOutbound: {
        'name': 'HK Node',
        'type': 'trojan',
        'server': 'example.com',
        'port': 443,
        'password': 'secret',
        'dialer-proxy': 'Litchi Cloud',
      },
    );

    final config = MihomoConfig.buildFullConfig([
      node,
    ], selectedTag: MihomoConfig.nodeTagFor(node))!;
    final proxy = (config['proxies'] as List).single as Map<String, dynamic>;

    expect(proxy.containsKey('dialer-proxy'), isFalse);
  });

  test('rewrites dialer-proxy references to generated node tags', () {
    const relay = NodeModel(
      id: 'relay',
      name: 'relay',
      flag: '',
      latency: 0,
      rawOutbound: {
        'name': 'Relay Node',
        'type': 'ss',
        'server': 'relay.example.com',
        'port': 443,
        'cipher': 'aes-128-gcm',
        'password': 'secret',
      },
    );
    const target = NodeModel(
      id: 'target',
      name: 'target',
      flag: '',
      latency: 0,
      rawOutbound: {
        'name': 'Target Node',
        'type': 'trojan',
        'server': 'target.example.com',
        'port': 443,
        'password': 'secret',
        'dialer-proxy': 'Relay Node',
      },
    );

    final config = MihomoConfig.buildFullConfig([
      relay,
      target,
    ], selectedTag: MihomoConfig.nodeTagFor(target))!;
    final proxies = (config['proxies'] as List).cast<Map<String, dynamic>>();
    final targetProxy = proxies.firstWhere(
      (proxy) => proxy['name'] == MihomoConfig.nodeTagFor(target),
    );

    expect(targetProxy['dialer-proxy'], MihomoConfig.nodeTagFor(relay));
  });

  test('repairs stale custom policy names in cached MATCH rules', () {
    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#hk',
    );
    final config = MihomoConfig.buildFullConfig(
      [node],
      selectedTag: MihomoConfig.nodeTagFor(node),
      rules: const [
        'DOMAIN-SUFFIX,example.com,Litchi Cloud',
        'MATCH,Litchi Cloud',
      ],
    )!;

    expect(config['rules'], ['DOMAIN-SUFFIX,example.com,PROXY', 'MATCH,PROXY']);
  });

  test('generated config passes the bundled mihomo validator', () async {
    final executable = Platform.environment['MIHOMO_EXE'];
    if (executable == null || !File(executable).existsSync()) return;

    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#hk',
    );
    final config = MihomoConfig.buildFullConfig([
      node,
    ], selectedTag: MihomoConfig.nodeTagFor(node))!;
    final directory = await Directory.systemTemp.createTemp(
      'litchi-mihomo-test-',
    );
    try {
      final file = File('${directory.path}/config.yaml');
      await file.writeAsString(MihomoConfig.encodeConfig(config));
      final result = await Process.run(executable, [
        '-d',
        directory.path,
        '-t',
        '-f',
        file.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

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
}

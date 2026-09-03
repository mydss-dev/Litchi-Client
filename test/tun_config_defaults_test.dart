import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/sing_box_config.dart';

void main() {
  const node = NodeModel(
    id: 'tun-test',
    name: 'TUN Test',
    flag: '',
    latency: 0,
    rawOutbound: {
      'type': 'trojan',
      'server': 'example.com',
      'server_port': 443,
      'password': 'secret',
      'tls': {'enabled': true, 'server_name': 'example.com'},
      '_litchi_format': 'sing-box',
    },
  );

  test('Windows TUN keeps conservative Wintun defaults', () {
    final profile = SingBoxConfig.tunRouteProfile(isWindows: true);
    expect(profile.mtu, 1500);
    expect(profile.strictRoute, isFalse);
  });

  test('non-Windows TUN keeps the existing route profile', () {
    final profile = SingBoxConfig.tunRouteProfile(isWindows: false);
    expect(profile.mtu, 9000);
    expect(profile.strictRoute, isTrue);
  });

  test('TUN config uses the current platform route profile', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
      networkMode: NetworkMode.tun,
    )!;

    final tun = (config['inbounds'] as List).cast<Map>().firstWhere(
      (inbound) => inbound['type'] == 'tun',
    );
    final profile = SingBoxConfig.tunRouteProfile(isWindows: Platform.isWindows);

    expect(tun['stack'], 'system');
    expect(tun['mtu'], profile.mtu);
    expect(tun['auto_route'], isTrue);
    expect(tun['strict_route'], profile.strictRoute);
  });

  test('main core sniffs, hijacks DNS, and keeps reverse mappings', () {
    final config = SingBoxConfig.buildFullConfig(
      const [node],
      selectedTag: SingBoxConfig.nodeTagFor(node),
      networkMode: NetworkMode.tun,
    )!;

    final routeRules = ((config['route'] as Map)['rules'] as List).cast<Map>();
    expect(routeRules[0], {'action': 'sniff'});
    expect(routeRules[1], {'protocol': 'dns', 'action': 'hijack-dns'});

    final dns = config['dns'] as Map;
    expect(dns['reverse_mapping'], isTrue);
  });
}

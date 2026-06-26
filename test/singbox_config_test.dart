import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/singbox_config.dart';

void main() {
  test('appDataDir is under a Litchi folder', () {
    expect(SingboxConfig.appDataDir(), contains('Litchi'));
  });

  test('buildFullConfig produces a config for a parseable node in global mode', () {
    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#hk',
    );
    final config = SingboxConfig.buildFullConfig(
      [node],
      selectedTag: SingboxConfig.nodeTagFor(node),
      proxyMode: ProxyMode.global,
    );
    expect(config, isNotNull);
    expect(config!['outbounds'], isA<List>());
  });

  test('rule mode still builds when bundled rule files are absent', () {
    const node = NodeModel(
      id: 'n1',
      name: 'hk',
      flag: '',
      latency: 0,
      rawUri: 'trojan://password@example.com:443#hk',
    );
    final config = SingboxConfig.buildFullConfig(
      [node],
      selectedTag: SingboxConfig.nodeTagFor(node),
      proxyMode: ProxyMode.rule,
    );

    expect(config, isNotNull);
    expect(config!['route'], isA<Map>());
  });
}

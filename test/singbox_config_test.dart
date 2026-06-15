import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/singbox_config.dart';

void main() {
  test('appDataDir is under a Litchi folder', () {
    expect(SingboxConfig.appDataDir(), contains('Litchi'));
  });

  test('buildFullConfig produces a config for a parseable node', () {
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
    );
    expect(config, isNotNull);
    expect(config!['outbounds'], isA<List>());
  });
}

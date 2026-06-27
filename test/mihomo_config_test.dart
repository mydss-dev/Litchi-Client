import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/mihomo_config.dart';

void main() {
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
    expect(config!['rules'], isA<List>());
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

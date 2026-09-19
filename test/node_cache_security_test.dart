import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_cache_service.dart';

const _node = NodeModel(
  id: '42',
  name: 'Hong Kong',
  flag: 'HK',
  latency: 15,
  server: 'private.example',
  port: 443,
  rawOutbound: {
    '_litchi_format': 'sing-box',
    'type': 'trojan',
    'server': 'private.example',
    'password': 'private-password',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late File publicCache;
  late File protectedCache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('litchi-p2-node-cache-');
    NodeCacheService.overrideCacheDirectoryForTesting(directory.path);
    publicCache = File('${directory.path}${Platform.pathSeparator}nodes_cache.json');
    protectedCache = File(
      '${directory.path}${Platform.pathSeparator}secure_nodes_cache.dpapi',
    );
  });

  tearDown(() async {
    await NodeCacheService.clear();
    NodeCacheService.overrideCacheDirectoryForTesting(null);
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('display cache never contains native node credentials', () async {
    await NodeCacheService.save([_node]);

    expect(await publicCache.exists(), isTrue);
    final raw = await publicCache.readAsString();
    expect(raw, contains('Hong Kong'));
    expect(raw, isNot(contains('private-password')));
    expect(raw, isNot(contains('private.example')));
    if (await protectedCache.exists()) {
      final protected = await protectedCache.readAsString();
      expect(protected, isNot(contains('private-password')));
    }
  });

  test('logout clear wins over previously queued asynchronous saves', () async {
    final first = NodeCacheService.save([_node]);
    final second = NodeCacheService.save([_node]);
    final cleared = NodeCacheService.clear();
    await Future.wait([first, second, cleared]);

    expect(await publicCache.exists(), isFalse);
    expect(await protectedCache.exists(), isFalse);
    expect(await NodeCacheService.load(), isEmpty);
  });

  test('legacy plaintext node cache is replaced with public-only data', () async {
    await publicCache.writeAsString(jsonEncode([_node.toJson()]));

    final recovered = await NodeCacheService.load();
    expect(recovered, hasLength(1));
    expect(recovered.single.hasConfig, isTrue);
    final raw = await publicCache.readAsString();
    expect(raw, isNot(contains('private-password')));
    expect(raw, isNot(contains('private.example')));
  });
}

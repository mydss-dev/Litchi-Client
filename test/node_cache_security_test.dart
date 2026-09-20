import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_cache_service.dart';

const _authDataA = 'token-for-user-alice';
const _authDataB = 'token-for-user-bob';

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
    await NodeCacheService.save([_node], _authDataA);

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
    final first = NodeCacheService.save([_node], _authDataA);
    final second = NodeCacheService.save([_node], _authDataA);
    final cleared = NodeCacheService.clear();
    await Future.wait([first, second, cleared]);

    expect(await publicCache.exists(), isFalse);
    expect(await protectedCache.exists(), isFalse);
    expect(await NodeCacheService.load(_authDataA), isEmpty);
  });

  test('UI cache read path strips credentials even if file contains them (P2-3)',
      () async {
    // Simulate a malicious or stale UI cache file that contains rawOutbound.
    // The read path must strip connectable fields so the file cannot be used
    // to inject attacker-controlled proxy outbounds.
    await publicCache.writeAsString(jsonEncode([_node.toJson()]));

    final recovered = await NodeCacheService.load(_authDataA);
    expect(recovered, hasLength(1));
    expect(recovered.single.name, 'Hong Kong');
    expect(recovered.single.hasConfig, isFalse);
    expect(recovered.single.server, isEmpty);
    expect(recovered.single.port, 0);
  });

  test('secure cache is bound to session fingerprint (P2-5)', () async {
    // User A saves nodes with their token.
    await NodeCacheService.save([_node], _authDataA);

    // User A can load them back with credentials intact.
    final forA = await NodeCacheService.load(_authDataA);
    expect(forA, hasLength(1));
    expect(forA.single.hasConfig, isTrue);

    // User B must NOT see user A's node credentials. The secure cache must
    // be rejected and deleted when the session fingerprint does not match.
    final forB = await NodeCacheService.load(_authDataB);
    expect(forB.single.hasConfig, isFalse);
    // The stale secure cache file should have been deleted.
    expect(await protectedCache.exists(), isFalse);
  });

  test('legacy plaintext node cache is replaced with public-only data', () async {
    await publicCache.writeAsString(jsonEncode([_node.toJson()]));

    // First load: migrates to secure cache but returns stripped nodes.
    final recovered = await NodeCacheService.load(_authDataA);
    expect(recovered, hasLength(1));
    expect(recovered.single.name, 'Hong Kong');
    expect(recovered.single.hasConfig, isFalse);

    // The public cache file must not contain credentials after migration.
    final raw = await publicCache.readAsString();
    expect(raw, isNot(contains('private-password')));
    expect(raw, isNot(contains('private.example')));
  });
}

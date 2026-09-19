import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/config/app_identity.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/account_summary_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = UserModel(
  name: 'tester',
  plan: 'Premium',
  avatarLetter: 'T',
  expiry: '2026-12-31',
  balance: 1250,
);
const _traffic = TrafficModel(totalGb: 100, usedGb: 25, remainGb: 75);

String get _cacheKey => AppIdentity.preferenceKey('account_summary_cache_v1');

String _legacyPayload(String session) => jsonEncode({
  'session': sha256.convert(utf8.encode(session)).toString(),
  'user': {
    'name': 'tester',
    'plan': 'Premium',
    'avatarLetter': 'T',
    'expiry': '2026-12-31',
    'balance': 1250,
  },
  'traffic': {'totalGb': 100, 'usedGb': 25, 'remainGb': 75},
  'expiredAt': 1798675200,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('never writes account information as plaintext preferences', () async {
    await AccountSummaryCache.save(
      'session-a',
      user: _user,
      traffic: _traffic,
      expiredAt: 1798675200,
    );

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_cacheKey);
    expect(stored, isNot(contains('tester')));
    expect(stored, isNot(contains('Premium')));
    expect(stored, isNot(contains('1250')));
    if (Platform.isLinux) {
      // Linux deliberately has no insecure fallback when the OS secure
      // backend is unavailable. The account still works without this cache.
      expect(stored, isNull);
      expect(await AccountSummaryCache.load('session-a'), isNull);
      return;
    }
    if (stored == null) return; // OS key store can reject unsigned test apps.

    final cached = await AccountSummaryCache.load('session-a');
    expect(cached?.user.plan, 'Premium');
    expect(cached?.user.expiry, '2026-12-31');
    expect(cached?.traffic.remainGb, 75);
    expect(cached?.expiredAt, 1798675200);
    expect(await AccountSummaryCache.load('session-b'), isNull);
    await AccountSummaryCache.clear();
  });

  test('migrates or removes old plaintext for the matching session', () async {
    SharedPreferences.setMockInitialValues({
      _cacheKey: _legacyPayload('session-a'),
    });

    final cached = await AccountSummaryCache.load('session-a');
    expect(cached?.user.name, 'tester');
    expect(cached?.traffic.remainGb, 75);
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_cacheKey);
    expect(stored, isNot(contains('tester')));
    expect(stored, isNot(contains('Premium')));
    if (Platform.isLinux) expect(stored, isNull);
    await AccountSummaryCache.clear();
  });

  test('deletes plaintext belonging to a different session', () async {
    SharedPreferences.setMockInitialValues({
      _cacheKey: _legacyPayload('session-a'),
    });

    expect(await AccountSummaryCache.load('session-b'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_cacheKey), isNull);
  });

  test('removes malformed legacy plaintext without returning it', () async {
    SharedPreferences.setMockInitialValues({_cacheKey: '{invalid json'});

    expect(await AccountSummaryCache.load('session-a'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_cacheKey), isNull);
  });

  test('clear removes legacy plaintext as well as protected references', () async {
    SharedPreferences.setMockInitialValues({
      _cacheKey: _legacyPayload('session-a'),
    });

    await AccountSummaryCache.clear();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_cacheKey), isNull);
    expect(await AccountSummaryCache.load('session-a'), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/account_summary_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores a summary only for the same authenticated session', () async {
    const user = UserModel(
      name: 'tester',
      plan: 'Premium',
      avatarLetter: 'T',
      expiry: '2026-12-31',
    );
    const traffic = TrafficModel(totalGb: 100, usedGb: 25, remainGb: 75);

    await AccountSummaryCache.save(
      'session-a',
      user: user,
      traffic: traffic,
      expiredAt: 1798675200,
    );

    final cached = await AccountSummaryCache.load('session-a');
    expect(cached?.user.plan, 'Premium');
    expect(cached?.user.expiry, '2026-12-31');
    expect(cached?.traffic.remainGb, 75);
    expect(cached?.expiredAt, 1798675200);
    expect(await AccountSummaryCache.load('session-b'), isNull);
  });

  test('clear removes the cached summary', () async {
    const user = UserModel(
      name: 'tester',
      plan: 'Premium',
      avatarLetter: 'T',
      expiry: '2026-12-31',
    );
    const traffic = TrafficModel(totalGb: 1, usedGb: 0, remainGb: 1);
    await AccountSummaryCache.save('session', user: user, traffic: traffic);

    await AccountSummaryCache.clear();

    expect(await AccountSummaryCache.load('session'), isNull);
  });
}

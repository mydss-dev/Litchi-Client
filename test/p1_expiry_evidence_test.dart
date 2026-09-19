import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/plan_presentation.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

RemoteUser _user({int? expiredAt, bool hasPlan = true}) {
  final data = <String, dynamic>{
    'id': 1,
    'email': 'test@example.com',
  };
  if (hasPlan) data['plan_id'] = 7;
  if (expiredAt != null) data['expired_at'] = expiredAt;
  return RemoteUser.fromJson(data);
}

void main() {
  test('missing expiry on a real plan is unknown, never permanent', () {
    final info = _user();
    final user = ModelMappers.toUser(info);
    expect(user.expiry, '未提供');

    final display = PlanPresentation.resolve(
      hasPlan: true,
      name: 'Litchi Ultra',
      subscribeStatus: info.subscribeStatus,
      expiredAt: info.expiredAt,
      expiryLabel: user.expiry,
      quotaGb: 512,
      remainingGb: 100,
      now: DateTime(2026, 9, 19),
    );
    expect(display.expiry, '有效期待同步');
    expect(display.status, '状态待同步');
    expect(display.usable, isFalse);
  });

  test('an explicit zero expiry retains permanent meaning', () {
    final user = ModelMappers.toUser(_user(expiredAt: 0));
    expect(user.expiry, '永久');
  });

  test('a positive expiry preserves the actual date', () {
    final timestamp = DateTime(2026, 12, 31).millisecondsSinceEpoch ~/ 1000;
    final user = ModelMappers.toUser(_user(expiredAt: timestamp));
    expect(user.expiry, '2026-12-31');
  });

  test('an account without a plan still has no expiry', () {
    final user = ModelMappers.toUser(_user(hasPlan: false));
    expect(user.expiry, isEmpty);
  });

  test('stale permanent label without timestamp proof becomes unknown', () {
    final label = PlanPresentation.expiryLabelWithEvidence(
      label: '永久',
      accountExpiry: null,
      subscriptionExpiry: null,
    );
    expect(label, '未提供');
  });

  test('subscription zero is proof of a permanent plan', () {
    final label = PlanPresentation.expiryLabelWithEvidence(
      label: '未提供',
      accountExpiry: null,
      subscriptionExpiry: 0,
    );
    expect(label, '永久');
    expect(
      PlanPresentation.expiryTimestampWithEvidence(
        accountExpiry: null,
        subscriptionExpiry: 0,
      ),
      0,
    );
  });

  test('dated expiry wins over a contradictory zero sentinel', () {
    const timestamp = 1798675200;
    expect(
      PlanPresentation.expiryTimestampWithEvidence(
        accountExpiry: timestamp,
        subscriptionExpiry: 0,
      ),
      timestamp,
    );
    expect(
      PlanPresentation.expiryLabelWithEvidence(
        label: '永久',
        accountExpiry: timestamp,
        subscriptionExpiry: 0,
      ),
      '未提供',
    );
  });
}

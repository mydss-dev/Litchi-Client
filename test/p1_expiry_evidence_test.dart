import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/plan_presentation.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

RemoteUser _user({int? expiredAt, bool hasPlan = true, bool explicitNull = false}) {
  final data = <String, dynamic>{
    'id': 1,
    'email': 'test@example.com',
  };
  if (hasPlan) data['plan_id'] = 7;
  if (explicitNull || expiredAt != null) data['expired_at'] = expiredAt;
  return RemoteUser.fromJson(data);
}

void main() {
  test('a panel null expiry on a real plan preserves permanent compatibility', () {
    final info = _user(explicitNull: true);
    final user = ModelMappers.toUser(info);
    expect(user.expiry, '永久');

    final label = PlanPresentation.expiryLabelWithEvidence(
      label: user.expiry,
      accountExpiry: info.expiredAt,
      subscriptionExpiry: null,
      confirmedAccountPlan: info.hasPlanEvidence,
    );
    final display = PlanPresentation.resolve(
      hasPlan: true,
      name: 'Litchi Ultra',
      subscribeStatus: info.subscribeStatus,
      expiredAt: info.expiredAt,
      expiryLabel: label,
      quotaGb: 512,
      remainingGb: 100,
      now: DateTime(2026, 9, 19),
    );
    expect(display.expiry, '永久有效');
    expect(display.status, '正常');
    expect(display.usable, isTrue);
  });

  test('an omitted expiry cannot be distinguished from null by current model', () {
    // The backend model documents null as permanent. Until the raw-field
    // presence is retained, preserve its established mapping instead of
    // misclassifying real lifetime subscribers as inactive.
    expect(ModelMappers.toUser(_user()).expiry, '永久');
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

  test('stale permanent label without confirmed account is unknown', () {
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
        confirmedAccountPlan: true,
      ),
      '未提供',
    );
  });
}

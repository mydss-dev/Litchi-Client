import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/models/model_mappers.dart';

void main() {
  test('maps extended billing cycles and sold-out inventory', () {
    final remote = RemotePlan.fromJson({
      'id': 7,
      'name': 'Long plan',
      'transfer_enable': 100,
      'two_year_price': 20000,
      'three_year_price': 27000,
      'capacity_limit': 0,
      'show': 1,
    });
    final plan = ModelMappers.toPlan(remote);

    expect(plan.category, PlanCategory.recurring);
    expect(plan.priceForCycle(BillingCycle.twoYears), 200);
    expect(plan.priceForCycle(BillingCycle.threeYears), 270);
    expect(plan.soldOut, isTrue);
  });

  test('hides billing periods serialized as zero by compatible panels', () {
    final remote = RemotePlan.fromJson({
      'id': 8,
      'name': 'Annual only',
      'transfer_enable': 100,
      'month_price': 0,
      'quarter_price': '0',
      'half_year_price': null,
      'year_price': 12000,
      'two_year_price': 0,
      'three_year_price': 0,
      'onetime_price': 0,
      'show': 1,
    });
    final plan = ModelMappers.toPlan(remote);

    expect(plan.category, PlanCategory.recurring);
    expect(plan.monthlyPrice, isNull);
    expect(plan.quarterlyPrice, isNull);
    expect(plan.yearlyPrice, 120);
    expect(plan.oneTimePrice, isNull);
  });

  test('reads plan id from nested user and subscription payloads', () {
    final user = RemoteUser.fromJson({
      'id': 1,
      'email': 'user@example.com',
      'subscribe': {'plan_id': '23'},
    });
    final subscribe = RemoteSubscribe.fromJson({
      'subscribe_url': 'https://example.com/sub',
      'plan': {'id': 24},
    });

    expect(user.planId, 23);
    expect(subscribe.planId, 24);
  });

  test('does not mistake a no-plan account for a permanent subscription', () {
    final user = RemoteUser.fromJson({
      'id': 1,
      'email': 'user@example.com',
      'plan_id': 0,
      'transfer_enable': 0,
      'expired_at': null,
      'subscribe_status': 1,
    });

    expect(user.hasPlanEvidence, isFalse);
    expect(user.planLabel, isEmpty);
    expect(user.expiryDisplay, isEmpty);
  });

  test('keeps a permanent plan when the backend provides plan evidence', () {
    final user = RemoteUser.fromJson({
      'id': 1,
      'email': 'user@example.com',
      'plan_id': 7,
      'expired_at': null,
    });

    expect(user.hasPlanEvidence, isTrue);
    expect(user.expiryDisplay, '永久');
  });

  test('formats order amounts with the backend currency symbol', () {
    const order = RemoteOrder(
      tradeNo: 'T1',
      period: 'month_price',
      totalAmount: 1234,
      status: 4,
      createdAt: 0,
    );

    expect(order.amountDisplay(r'$'), r'$12.34');
    expect(order.statusLabel, '已折抵');
  });

  test('combines fixed and percentage payment handling fees', () {
    const method = RemotePaymentMethod(
      id: 1,
      name: 'Card',
      handlingFeeFixed: 30,
      handlingFeePercent: 2.5,
    );

    expect(method.feeForAmount(1000), 55);
  });
}

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

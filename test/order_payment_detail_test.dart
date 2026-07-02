import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';

void main() {
  test('detects a fully balance-paid order from backend order detail', () {
    final detail = RemoteOrderPaymentDetail.fromJson({
      'total_amount': 0,
      'balance_amount': 1200,
      'status': 0,
    });

    expect(detail.usedBalance, isTrue);
    expect(detail.balanceOnly, isTrue);
  });

  test('keeps the external amount due after a partial balance deduction', () {
    final detail = RemoteOrderPaymentDetail.fromJson({
      'total_amount': 800,
      'discount_amount': 100,
      'surplus_amount': 200,
      'balance_amount': 400,
      'refund_amount': 50,
      'pre_handling_amount': 25,
      'status': 0,
    });

    expect(detail.totalAmount, 800);
    expect(detail.discountAmount, 100);
    expect(detail.surplusAmount, 200);
    expect(detail.usedBalance, isTrue);
    expect(detail.refundAmount, 50);
    expect(detail.preHandlingAmount, 25);
    expect(detail.balanceOnly, isFalse);
  });

  test('does not infer balance support when the field is absent', () {
    final detail = RemoteOrderPaymentDetail.fromJson({
      'total_amount': 1200,
      'status': 0,
    });

    expect(detail.balanceAmount, isNull);
    expect(detail.usedBalance, isFalse);
    expect(detail.balanceOnly, isFalse);
  });
}

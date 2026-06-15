import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/commission_validation_service.dart';

void main() {
  group('transfer validation', () {
    test('rejects unavailable or invalid transfer amounts', () {
      expect(
        CommissionValidationService.validateTransfer(
          amount: 10,
          withdrawable: 0,
        ),
        '暂无可划转佣金',
      );
      expect(
        CommissionValidationService.validateTransfer(
          amount: 0,
          withdrawable: 10,
        ),
        '请输入划转金额',
      );
      expect(
        CommissionValidationService.validateTransfer(
          amount: 20,
          withdrawable: 10,
        ),
        '划转金额不能超过可提现佣金',
      );
    });

    test('accepts valid transfer amount', () {
      expect(
        CommissionValidationService.validateTransfer(
          amount: 10,
          withdrawable: 10,
        ),
        isNull,
      );
    });
  });

  group('withdraw validation', () {
    String? validate({
      double amount = 20,
      double withdrawable = 50,
      bool withdrawEnabled = true,
      double minWithdrawAmount = 10,
      String account = 'user@example.com',
      String method = '支付宝',
      List<String> withdrawMethods = const ['支付宝', '银行卡'],
    }) {
      return CommissionValidationService.validateWithdraw(
        amount: amount,
        withdrawable: withdrawable,
        withdrawEnabled: withdrawEnabled,
        minWithdrawAmount: minWithdrawAmount,
        currencySymbol: '¥',
        account: account,
        method: method,
        withdrawMethods: withdrawMethods,
      );
    }

    test('rejects invalid withdraw inputs in priority order', () {
      expect(validate(amount: 0), '请输入提现金额');
      expect(validate(withdrawEnabled: false), '提现暂未开放');
      expect(validate(amount: 60), '提现金额不能超过可提现佣金');
      expect(validate(amount: 5), '最低提现金额为 ¥10.00');
      expect(validate(account: '  '), '请输入提现账户');
      expect(validate(method: '  '), '请输入提现方式');
      expect(validate(method: '微信'), '请选择可用的提现方式');
    });

    test('accepts valid withdraw request and trims are handled by caller', () {
      expect(validate(), isNull);
      expect(validate(account: ' user@example.com ', method: ' 支付宝 '), isNull);
    });
  });
}

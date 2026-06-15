import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/wallet_controller.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

void main() {
  // The API is never reached in these tests — every action fails validation
  // first, so an unconfigured client is sufficient.
  WalletController build() =>
      WalletController(PanelApi(ApiClient()), () async {});

  test('applySnapshot updates the exposed getters', () {
    final c = build();
    c.applySnapshot(
      withdrawable: 12.5,
      commissionRate: 0.2,
      invitedCount: 3,
      currencySymbol: r'$',
    );
    expect(c.withdrawable, 12.5);
    expect(c.commissionRate, 0.2);
    expect(c.invitedCount, 3);
    expect(c.currencySymbol, r'$');
  });

  test('setCurrencySymbol ignores empty values', () {
    final c = build();
    final before = c.currencySymbol;
    c.setCurrencySymbol('');
    expect(c.currencySymbol, before);
    c.setCurrencySymbol('€');
    expect(c.currencySymbol, '€');
  });

  test('reset restores defaults', () {
    final c = build();
    c.applySnapshot(withdrawable: 99);
    c.reset();
    expect(c.withdrawable, 0);
  });

  test('transferAllCommission rejects when nothing is withdrawable', () async {
    final c = build();
    final error = await c.transferAllCommission();
    expect(error, '暂无可划转佣金');
  });

  test('withdrawCommission rejects a zero amount before any network call', () async {
    final c = build();
    final error = await c.withdrawCommission(
      amount: 0,
      account: 'acc',
      method: 'usdt',
    );
    expect(error, '请输入提现金额');
  });
}

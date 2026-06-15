import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/wallet_data_state.dart';

void main() {
  test('defaults to a locked empty wallet state', () {
    const wallet = WalletDataState();

    expect(wallet.withdrawable, 0);
    expect(wallet.withdrawEnabled, isFalse);
    expect(wallet.currencySymbol, '¥');
    expect(wallet.withdrawMethods, isEmpty);
  });

  test('copyWith preserves existing fields when values are omitted', () {
    const wallet = WalletDataState(
      withdrawable: 88,
      withdrawClose: 0,
      currencySymbol: 'HK\$',
    );

    final updated = wallet.copyWith(commissionRate: 0.2);

    expect(updated.withdrawable, 88);
    expect(updated.withdrawEnabled, isTrue);
    expect(updated.currencySymbol, 'HK\$');
    expect(updated.commissionRate, 0.2);
  });
}

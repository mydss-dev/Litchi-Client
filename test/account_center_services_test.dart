import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';

void main() {
  test('RemoteUser keeps XiaoV2Board Telegram binding state', () {
    final bound = RemoteUser.fromJson({
      'email': '191066639@example.com',
      'telegram_id': 123456789,
    });
    final unbound = RemoteUser.fromJson({
      'email': '191066639@example.com',
      'telegram_id': null,
    });

    expect(bound.telegramId, '123456789');
    expect(unbound.telegramId, isNull);
  });

  test(
    'desktop account uses one funds section instead of duplicate status cards',
    () {
      final source = File('lib/features/account/account_page.dart')
          .readAsStringSync();

      expect(source, contains('class _DesktopFundsAccount'));
      expect(source, isNot(contains('class _DesktopAccountMetrics')));
      expect(source, contains("hans: '划转佣金'"));
      expect(source, contains("hans: '申请提现'"));
      expect(source, contains('class _GiftCardRedeemModal'));
      expect(source, contains('class _TelegramBindingModal'));
    },
  );

  test('panel API keeps XiaoV2Board gift card and Telegram endpoints', () {
    final source = File('lib/shared/services/panel_api.dart')
        .readAsStringSync();

    expect(source, contains("'/user/redeemgiftcard'"));
    expect(source, contains("'/user/telegram/getBotInfo'"));
    expect(source, contains("'/user/unbindTelegram'"));
  });
}

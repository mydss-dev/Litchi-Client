import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';

void main() {
  final items = [
    ...kMobilePrimary, ...kMobileHub, ...kMobileMore,
    ...kDesktopRail, kRailSettings,
  ];

  Future<void> check(WidgetTester tester, Locale locale,
      Map<AppPage, String> expected) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (context) {
        for (final item in items) {
          if (expected.containsKey(item.page)) {
            expect(item.localizedLabel(context), expected[item.page],
              reason: '${locale.toLanguageTag()}: ${item.page.name}');
          }
        }
        return const SizedBox.shrink();
      })),
    ));
    expect(tester.takeException(), isNull);
  }

  testWidgets('English navigation contains no hard-coded Chinese labels',
      (tester) async {
    await check(tester, const Locale('en'), {
      AppPage.dashboard: 'Connect',
      AppPage.nodes: 'Nodes',
      AppPage.shop: 'Plans',
      AppPage.account: 'Account',
      AppPage.more: 'More',
      AppPage.orders: 'Orders',
      AppPage.traffic: 'Traffic',
      AppPage.invite: 'Invite friends',
      AppPage.tickets: 'Support',
      AppPage.settings: 'Client settings',
      AppPage.giftCard: 'Gift card redemption',
    });
  });

  testWidgets('Simplified Chinese navigation labels are localized',
      (tester) async {
    await check(tester, const Locale('zh'), {
      AppPage.dashboard: '连接',
      AppPage.nodes: '节点',
      AppPage.shop: '套餐',
      AppPage.account: '我的',
      AppPage.more: '更多',
      AppPage.orders: '订单记录',
      AppPage.traffic: '流量用量',
      AppPage.invite: '邀请好友',
      AppPage.tickets: '工单支持',
      AppPage.settings: '客户端设置',
      AppPage.giftCard: '礼品卡兑换',
    });
  });

  testWidgets('Traditional Chinese uses its localized account label',
      (tester) async {
    await check(tester, const Locale('zh', 'TW'), {
      AppPage.account: '我的',
    });
  });
}

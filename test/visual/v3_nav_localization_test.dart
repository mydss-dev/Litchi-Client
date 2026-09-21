import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';

void main() {
  final items = [
    ...kMobilePrimary, ...kMobileMore,
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

  testWidgets('Simplified Chinese uses two-character navigation labels',
      (tester) async {
    await check(tester, const Locale('zh'), {
      AppPage.dashboard: '连接',
      AppPage.nodes: '节点',
      AppPage.shop: '套餐',
      AppPage.account: '我的',
      AppPage.more: '更多',
      AppPage.orders: '订单',
      AppPage.traffic: '流量',
      AppPage.invite: '邀请',
      AppPage.tickets: '工单',
      AppPage.settings: '设置',
      AppPage.giftCard: '兑换中心',
    });
  });

  testWidgets('Traditional Chinese uses localized short labels throughout',
      (tester) async {
    await check(tester, const Locale('zh', 'TW'), {
      AppPage.dashboard: '連線',
      AppPage.nodes: '節點',
      AppPage.shop: '套餐',
      AppPage.account: '我的',
      AppPage.more: '更多',
      AppPage.orders: '訂單',
      AppPage.traffic: '流量',
      AppPage.invite: '邀請',
      AppPage.tickets: '工單',
      AppPage.settings: '設定',
      AppPage.giftCard: '兌換中心',
    });
  });
}

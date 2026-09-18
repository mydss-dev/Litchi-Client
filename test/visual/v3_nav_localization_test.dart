import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_nav_localization.dart';

void main() {
  Future<void> check(WidgetTester tester, Locale locale,
      Map<AppPage, String> expected) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (context) {
        final labels = [
          ...kMobilePrimary,
          ...kMobileHub,
          ...kMobileMore,
          ...kDesktopRail,
          kRailSettings,
        ];
        for (final item in labels) {
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
      AppPage.traffic: 'Usage',
      AppPage.invite: 'Invite',
      AppPage.settings: 'Settings',
    });
  });

  testWidgets('Simplified Chinese retains existing navigation labels',
      (tester) async {
    await check(tester, const Locale('zh'), {
      AppPage.dashboard: '连接',
      AppPage.nodes: '节点',
      AppPage.shop: '套餐',
      AppPage.account: '账户',
      AppPage.more: '更多',
      AppPage.orders: '订单记录',
      AppPage.traffic: '流量',
      AppPage.invite: '邀请',
      AppPage.settings: '设置',
    });
  });

  testWidgets('Traditional Chinese uses its localized account label',
      (tester) async {
    await check(tester, const Locale('zh', 'TW'), {
      AppPage.account: '我的',
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_nav_localization.dart';

void main() {
  final items = [
    ...kMobilePrimary, ...kMobileHub, ...kMobileMore,
    ...kDesktopRail, kRailSettings,
  ];

  Future<void> check(WidgetTester tester, Locale locale,
      Map<AppPage, String> expected, {bool preserveOriginal = false}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: (context) {
        for (final item in items) {
          if (preserveOriginal) {
            expect(item.localizedLabel(context), item.label,
              reason: '${locale.toLanguageTag()}: ${item.page.name}');
          } else if (expected.containsKey(item.page)) {
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

  testWidgets('Simplified Chinese keeps each original navigation label',
      (tester) async {
    // The mobile More entries deliberately have longer labels than the rail.
    await check(tester, const Locale('zh'), const {}, preserveOriginal: true);
  });

  testWidgets('Traditional Chinese uses its localized account label',
      (tester) async {
    await check(tester, const Locale('zh', 'TW'), {
      AppPage.account: '我的',
    });
  });
}

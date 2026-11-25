import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

void main() {
  testWidgets('mobile shop uses category filters and per-plan backend cycles',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = VisualV3Controller(AppPage.shop);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: V3ShopPage()),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('套餐订阅'), findsOneWidget);
    expect(find.text('可购买套餐'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-recurring')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-once')), findsOneWidget);
    expect(find.text('查看套餐说明'), findsNothing);
    expect(find.text('仅显示已配置周期'), findsNothing);

    // Plan name and price are side-by-side; the top category glyph is gone.
    final title = find.text('Litchi Ultra · 512G');
    final monthlyPrice = find.text('12.80');
    await tester.ensureVisible(title);
    expect(tester.getRect(monthlyPrice).left,
      greaterThan(tester.getRect(title).left));
    expect(find.text('周期套餐'), findsNothing);

    final quarter = find.byKey(const ValueKey('shop-cycle-8-quarterly'));
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pumpAndSettle();
    expect(find.text('34.80'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('shop-filter-once')));
    await tester.tap(find.byKey(const ValueKey('shop-filter-once')));
    await tester.pumpAndSettle();
    expect(find.text('300G 流量包'), findsOneWidget);
    expect(find.text('Litchi Ultra · 512G'), findsNothing);
    // One-time plans must not show a faux period/purchase button above CTA.
    expect(find.text('一次性购买'), findsNothing);
    expect(find.text('购买方式'), findsNothing);
    expect(find.widgetWithText(FilledButton, '选择此套餐'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-cycle-10-monthly')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

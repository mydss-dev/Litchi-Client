import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/pages/v3_account_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

Future<void> _pumpMobile(
  WidgetTester tester, VisualV3Controller controller, Widget page, {
  ThemeData? theme,
  Size size = const Size(390, 844),
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(
      theme: theme ?? V3Theme.light(),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: page),
    ),
  ));
  await tester.pumpAndSettle();
}

class _PlanRouteController extends VisualV3Controller {
  _PlanRouteController() : super(AppPage.account);
  AppPage _selected = AppPage.account;
  @override
  AppPage get page => _selected;
  @override
  void goToPage(AppPage page) {
    _selected = page;
    notifyListeners();
  }
}

void main() {
  testWidgets('approved V3 mobile account keeps actual actions and hero',
      (tester) async {
    final controller = VisualV3Controller(AppPage.account);
    await _pumpMobile(tester, controller, const V3AccountPage());
    expect(find.text('账户与订阅管理'), findsOneWidget);
    expect(find.text('已登录账户'), findsNothing);
    expect(find.text('Litchi User'), findsNothing);
    expect(find.text('litchi-user@example.com'), findsOneWidget);
    expect(find.text('管理账户'), findsOneWidget);
    expect(find.text('订阅计划'), findsOneWidget);
    expect(find.text('账户服务'), findsOneWidget);
    expect(find.text('流量用量'), findsNothing);
    expect(find.text('订单记录'), findsOneWidget);
    expect(find.text('工单支持'), findsOneWidget);
    expect(find.text('应用设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact account plan card opens real usage page',
      (tester) async {
    final controller = _PlanRouteController();
    await _pumpMobile(tester, controller, const V3AccountPage());
    final card = find.byKey(const ValueKey('v3-mobile-plan-card'));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    expect(controller.page, AppPage.traffic);
    expect(tester.takeException(), isNull);
  });

  testWidgets('usage page shows quota directly without duplicating plan card',
      (tester) async {
    final controller = VisualV3Controller(AppPage.traffic);
    await _pumpMobile(tester, controller, const V3TrafficPage());
    expect(find.byKey(const ValueKey('v3-mobile-plan-card')), findsNothing);
    expect(find.text('订阅计划'), findsNothing);
    expect(find.text('套餐流量'), findsOneWidget);
    expect(find.text('套餐'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-usage-renew')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved V15 mobile plans preserve independent backend prices',
      (tester) async {
    final controller = VisualV3Controller(AppPage.shop);
    await _pumpMobile(tester, controller, const V3ShopPage());
    expect(find.text('套餐订阅'), findsOneWidget);
    expect(find.text('选择适合你的连接与流量方案'), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-recurring')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('shop-filter-once')), findsOneWidget);
    expect(find.text('查看套餐说明'), findsNothing);

    final title = find.text('Litchi Ultra · 512G');
    final amount = find.byKey(const ValueKey('shop-price-8'));
    await tester.ensureVisible(title);
    expect(tester.getRect(amount).left, greaterThan(tester.getRect(title).left));
    expect(find.text('12.80'), findsOneWidget);
    expect(find.text('★ 推荐'), findsWidgets);

    final quarter = find.byKey(const ValueKey('shop-cycle-8-quarterly'));
    await tester.ensureVisible(quarter);
    await tester.tap(quarter);
    await tester.pumpAndSettle();
    expect(find.text('34.80'), findsOneWidget);

    final once = find.byKey(const ValueKey('shop-filter-once'));
    await tester.ensureVisible(once);
    await tester.tap(once);
    await tester.pumpAndSettle();
    expect(find.text('300G 流量包'), findsOneWidget);
    expect(find.text('叠加使用'), findsOneWidget);
    expect(find.text('一次性购买'), findsNothing);
    expect(find.text('购买方式'), findsNothing);
    expect(find.byKey(const ValueKey('shop-buy-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-cycle-10-monthly')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved account expiry footer stays usable at 320dp',
      (tester) async {
    final controller = VisualV3Controller(AppPage.account);
    await _pumpMobile(tester, controller, const V3AccountPage(),
        size: const Size(320, 720));
    await tester.ensureVisible(find.text('到期日期'));
    await tester.pumpAndSettle();
    expect(find.text('剩余有效期'), findsOneWidget);
    expect(find.text('续费'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('approved compact mobile plans do not overflow at 320dp',
      (tester) async {
    final controller = VisualV3Controller(AppPage.shop);
    await _pumpMobile(tester, controller, const V3ShopPage(),
        size: const Size(320, 720));
    expect(find.byKey(const ValueKey('shop-mobile-plan-8')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

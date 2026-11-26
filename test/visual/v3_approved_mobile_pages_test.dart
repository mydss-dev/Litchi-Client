import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/plan_presentation.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/pages/v3_account_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_mobile_plan_card.dart';

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

class _NoPlanRouteController extends _PlanRouteController {
  @override
  bool get hasPlan => false;
}

void main() {
  testWidgets('mobile account has one invite entry and no notifications row',
      (tester) async {
    final controller = VisualV3Controller(AppPage.account);
    await _pumpMobile(tester, controller, const V3AccountPage());
    expect(find.text('账户与订阅管理'), findsOneWidget);
    expect(find.text('已登录账户'), findsNothing);
    expect(find.text('Litchi User'), findsNothing);
    expect(find.text('litchi-user@example.com'), findsOneWidget);
    expect(find.text('管理账户'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-account-identity-avatar')),
        findsOneWidget);
    final identity = find.byKey(const ValueKey('v3-account-identity-card'));
    final plan = find.byKey(const ValueKey('v3-mobile-plan-summary'));
    final email = find.text('litchi-user@example.com');
    final usage = find.byKey(const ValueKey('v3-account-usage'));
    expect(find.descendant(of: identity, matching: plan), findsOneWidget);
    expect(find.text('Litchi Ultra · 512G'), findsOneWidget);
    expect(tester.getRect(email).left, tester.getRect(plan).left);
    expect(tester.getRect(email).bottom, lessThan(tester.getRect(plan).top));
    expect(tester.getRect(plan).bottom, lessThan(tester.getRect(usage).top));
    final days = find.text('剩余天数');
    final data = find.text('剩余流量');
    final usageValue = find.descendant(of: usage, matching: find.text('383.6 GB'));
    expect(days, findsOneWidget);
    expect(data, findsOneWidget);
    expect(tester.getRect(days).top, tester.getRect(data).top);
    expect(tester.getRect(data).bottom, lessThan(tester.getRect(usageValue).top));
    expect(find.text('邀请人数'), findsNothing);
    final invite = find.byKey(const ValueKey('v3-account-invite-banner'));
    final wallet = find.text('我的钱包');
    expect(tester.getRect(identity).bottom, lessThan(tester.getRect(invite).top));
    expect(tester.getRect(invite).bottom, lessThan(tester.getRect(wallet).top));
    expect(find.text('邀请好友'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-account-open-invite')), findsOneWidget);
    expect(find.text('通知'), findsNothing);
    expect(find.byKey(const ValueKey('v3-account-plan-status')), findsNothing);
    expect(find.byKey(const ValueKey('v3-account-renew')), findsNothing);
    expect(find.text('订单记录'), findsOneWidget);
    expect(find.text('工单支持'), findsOneWidget);
    expect(find.text('应用设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account traffic metric opens usage; invitation opens invite page',
      (tester) async {
    final controller = _PlanRouteController();
    await _pumpMobile(tester, controller, const V3AccountPage());
    await tester.tap(find.byKey(const ValueKey('v3-account-usage')));
    await tester.pumpAndSettle();
    expect(controller.page, AppPage.traffic);
    await tester.tap(find.byKey(const ValueKey('v3-account-open-invite')));
    await tester.pumpAndSettle();
    expect(controller.page, AppPage.invite);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account without a subscription opens the plan shop',
      (tester) async {
    final controller = _NoPlanRouteController();
    await _pumpMobile(tester, controller, const V3AccountPage());
    await tester.tap(find.text('管理账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('v3-account-renew')));
    await tester.pumpAndSettle();
    expect(controller.page, AppPage.shop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renewal is prominent only near expiry and hidden for permanent plans',
      (tester) async {
    final controller = VisualV3Controller(AppPage.account);
    final expiration = ValueNotifier<int?>(30);
    addTearDown(expiration.dispose);
    await _pumpMobile(tester, controller, ValueListenableBuilder<int?>(
      valueListenable: expiration,
      builder: (context, days, _) => V3MobilePlanSummary(
        plan: PlanPresentation(
          name: 'Test plan', usable: true, statusKind: PlanStatus.normal,
          expiryKind: days == null ? PlanExpiryKind.permanent : PlanExpiryKind.date,
          expiryDate: days == null ? null : DateTime.now().add(Duration(days: days)),
        ),
        onRenew: () {},
      ),
    ));
    final action = find.byKey(const ValueKey('v3-account-renew'));
    expect(tester.widget(action), isA<TextButton>());
    expiration.value = 3;
    await tester.pumpAndSettle();
    expect(tester.widget(action), isA<FilledButton>());
    expiration.value = null;
    await tester.pumpAndSettle();
    expect(action, findsNothing);
  });

  testWidgets('usage page shows quota directly without duplicating plan card',
      (tester) async {
    final controller = VisualV3Controller(AppPage.traffic);
    await _pumpMobile(tester, controller, const V3TrafficPage());
    expect(find.byType(V3MobilePlanSummary), findsNothing);
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
    expect(find.text('套餐'), findsOneWidget);
    expect(find.text('选择适合你的方案'), findsOneWidget);
    expect(find.text('套餐订阅'), findsNothing);
    expect(find.text('可购买套餐'), findsNothing);
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
    final details = find.byKey(const ValueKey('shop-details-8'));
    expect(find.text('高速线路'), findsNothing);
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('高速线路'), findsOneWidget);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.text('高速线路'), findsNothing);

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
    expect(find.text('叠加使用'), findsNothing);
    final onceDetails = find.byKey(const ValueKey('shop-details-10'));
    await tester.ensureVisible(onceDetails);
    await tester.tap(onceDetails);
    await tester.pumpAndSettle();
    expect(find.text('叠加使用'), findsOneWidget);
    expect(find.text('一次性购买'), findsNothing);
    expect(find.text('购买方式'), findsNothing);
    expect(find.byKey(const ValueKey('shop-buy-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-cycle-10-monthly')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ardot dark account layout stays usable at 320dp',
      (tester) async {
    final controller = VisualV3Controller(AppPage.account);
    await _pumpMobile(tester, controller, const V3AccountPage(),
        theme: V3Theme.dark(), size: const Size(320, 720));
    expect(find.text('剩余天数'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('管理账户'));
    await tester.pumpAndSettle();
    final renew = find.byKey(const ValueKey('v3-account-renew'));
    await tester.ensureVisible(renew);
    expect(tester.getRect(renew).height, greaterThanOrEqualTo(44));
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

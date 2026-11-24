import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_gift_card_page.dart';
import 'package:litchi_client/v3/pages/v3_orders_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_nav_island.dart';

import 'v3_visual_fixture.dart';

class _NavController extends VisualV3Controller {
  _NavController() : super(AppPage.dashboard);
  AppPage _current = AppPage.dashboard;
  @override
  AppPage get page => _current;
  @override
  void goToPage(AppPage target) {
    if (!isPageEnabled(target)) return;
    _current = target;
    notifyListeners();
  }
}

const _desktop = Size(900, 700);
const _mobile = Size(390, 844);

Future<_NavController> _pumpShell(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _NavController();
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        locale: const Locale('zh'),
        theme: V3Theme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const V3Shell(),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

Type _sheetType(AppPage page) => switch (page) {
  AppPage.orders => V3OrdersPage,
  AppPage.giftCard => V3GiftCardPage,
  _ => throw ArgumentError('${page.name} is not a compact sheet'),
};

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Finder _rail(AppPage page) => find.byKey(railItemKey(page));
// §13.3: the bottom bar is the floating island (V3NavIsland), not a
// NavigationBar — tabs are found by their label inside the island.
Finder _tab(String label) =>
    find.descendant(of: find.byType(V3NavIsland), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

String _primaryLabel(AppPage page) {
  // Return the Chinese label for mobile primary nav items.
  // This matches the zh locale set in _pumpShell and the actual
  // localization strings in app_zh.arb.
  return switch (page) {
    AppPage.dashboard => '连接',
    AppPage.nodes => '节点',
    AppPage.shop => '套餐',
    AppPage.account => '我的',
    AppPage.more => '更多',
    AppPage.traffic => '流量用量',
    AppPage.invite => '邀请好友',
    AppPage.tickets => '工单支持',
    AppPage.settings => '客户端设置',
    AppPage.orders => '订单记录',
    AppPage.giftCard => '礼品卡兑换',
  };
}

void main() {
  final reachable = AppPage.values.where(isPageEnabled).toList();
  final desktopReachable = reachable.where((page) => page != AppPage.more);

  for (final target in desktopReachable) {
    testWidgets('desktop can reach ${target.name}', (tester) async {
      await _onPlatform(TargetPlatform.windows, () async {
        final controller = await _pumpShell(tester, _desktop);
        await tester.pumpAndSettle();
        switch (target) {
          case AppPage.dashboard:
          case AppPage.nodes:
          case AppPage.shop:
          case AppPage.orders:
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            await _tap(tester, _rail(target), target.name);
          case AppPage.account:
            await _tap(tester, find.byKey(kAccountCardKey), 'account card');
          case AppPage.giftCard:
            await _tap(tester, find.byKey(kWindowGiftCardKey), target.name);
            expect(
              find.byType(_sheetType(target)),
              findsOneWidget,
              reason: '${target.name} must open from the window bar',
            );
            expect(
              controller.page,
              AppPage.dashboard,
              reason: '${target.name} is a window-bar sheet, not a page',
            );
            return;
          case AppPage.more:
            return;
        }
        expect(
          controller.page,
          target,
          reason: '${target.name} must be reachable from the desktop rail',
        );
      });
    });
  }

  for (final target in reachable) {
    testWidgets('mobile can reach ${target.name}', (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final controller = await _pumpShell(tester, _mobile);
        await tester.pumpAndSettle();
        switch (target) {
          case AppPage.dashboard:
          case AppPage.nodes:
          case AppPage.shop:
          case AppPage.account:
            await _tap(tester, _tab(_primaryLabel(target)), target.name);
          case AppPage.more:
            // §13.3: the 更多 tab is deleted; the route stays compatible but
            // is no longer a bottom-bar destination, so nothing to tap here.
            return;
          case AppPage.orders:
            // Orders is a full page from the account hub, not a modal.
            await _tap(tester, _tab(_primaryLabel(AppPage.account)), 'account tab');
            await _tap(tester, find.byKey(hubRowKey(AppPage.orders)), 'orders hub');
            expect(find.byType(V3OrdersPage), findsOneWidget,
              reason: 'orders must open from the 我的 hub');
            expect(controller.page, AppPage.orders,
              reason: 'orders must be a real full-screen page');
            await _tap(tester, find.byTooltip('返回我的'), 'orders back');
            expect(controller.page, AppPage.account);
            return;
          case AppPage.giftCard:
            // §13.3: redemption folds into the shop strip.
            await _tap(tester, _tab(_primaryLabel(AppPage.shop)), 'shop tab');
            await _tap(tester, find.text('立即兑换'), 'shop redeem strip');
            expect(find.byType(V3GiftCardPage), findsOneWidget,
              reason: 'gift card must open from the shop strip');
            expect(controller.page, AppPage.shop,
              reason: 'redemption is a sheet over the shop');
            await _tap(tester, find.byTooltip('关闭'), 'gift sheet close');
            return;
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            // §13.3: the overflow surfaces live as long rows inside 我的.
            await _tap(tester, _tab(_primaryLabel(AppPage.account)), 'account tab');
            await _tap(tester, find.byKey(hubRowKey(target)), '${target.name} hub');
        }
        expect(
          controller.page,
          target,
          reason: '${target.name} must be reachable at 390dp',
        );
      });
    });
  }

  test('every enabled page is declared in the nav model', () {
    for (final surface in <(String, List<V3NavItem>)>[
      ('kMobilePrimary', kMobilePrimary),
      ('kMobileMore', kMobileMore),
      ('kDesktopRail', kDesktopRail),
    ]) {
      final (name, items) = surface;
      final seen = <AppPage>{};
      for (final item in items) {
        expect(
          seen.add(item.page),
          isTrue,
          reason: '${item.page.name} is declared twice in $name',
        );
      }
    }
    final declared = {
      ...kMobilePrimary.map((item) => item.page),
      ...kMobileMore.map((item) => item.page),
      ...kDesktopRail.map((item) => item.page),
    };
    // §13.3 test change reason: the 更多 tab is deleted, so AppPage.more is no
    // longer a nav surface; its route stays compatible (the more-sheet test
    // below) but the nav model no longer declares it.
    for (final page in AppPage.values.where((page) => page != AppPage.more)) {
      expect(
        declared.contains(page),
        isTrue,
        reason: '${page.name} is missing from the nav model entirely',
      );
    }
  });

  testWidgets('overflow pages highlight the 我的 tab', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      // §13.3 test change reason: 更多 is deleted, so the overflow pages now
      // highlight the tab that leads to them — 我的.
      final accountIndex = enabledNavItems(
        kMobilePrimary,
      ).indexWhere((item) => item.page == AppPage.account);
      expect(accountIndex, isNonNegative);
      for (final page in enabledNavItems(
        kMobileMore,
      ).map((item) => item.page)) {
        controller.goToPage(page);
        await tester.pumpAndSettle();
        expect(
          tester.widget<V3NavIsland>(find.byType(V3NavIsland)).selectedIndex,
          accountIndex,
          reason: '${page.name} should highlight 我的',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'inline wallet actions open their own dialogs and remain visible',
    (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final controller = await _pumpShell(tester, _mobile);
        controller.goToPage(AppPage.account);
        await tester.pumpAndSettle();
        expect(find.text('钱包余额'), findsOneWidget);
        expect(
          find.text('可提现'),
          findsOneWidget,
          reason: 'commission must be visible without opening a wallet sheet',
        );
        expect(
          find.text('累计佣金'),
          findsOneWidget,
          reason: 'commission belongs to the inline wallet card',
        );
        const actionTitles = ['充值余额', '申请提现', '佣金转余额'];
        for (final (label, dialogTitle) in <(String, String)>[
          ('充值', '充值余额'),
          ('提现', '申请提现'),
          ('划转', '佣金转余额'),
        ]) {
          await _tap(tester, find.text(label), label);
          expect(
            find.text(dialogTitle),
            findsOneWidget,
            reason: '$label must open its own dialog',
          );
          for (final other in actionTitles.where(
            (title) => title != dialogTitle,
          )) {
            expect(
              find.text(other),
              findsNothing,
              reason: '$label must not open unrelated dialogs',
            );
          }
          final activeDialog = find
              .ancestor(
                of: find.text(dialogTitle),
                matching: find.byType(Dialog),
              )
              .first;
          expect(activeDialog, findsOneWidget);
          await _tap(
            tester,
            find.descendant(of: activeDialog, matching: find.byTooltip('关闭')),
            '$label dialog close',
          );
          expect(find.text(dialogTitle), findsNothing);
          expect(
            find.text('可提现'),
            findsOneWidget,
            reason: 'closing dialog returns to visible wallet area',
          );
          expect(controller.page, AppPage.account);
        }
        expect(controller.page, AppPage.account);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('orders page returns to 我的 and gift sheet returns to 套餐',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      // Orders: 我的 hub row opens a page; back returns to 我的.
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(hubRowKey(AppPage.orders)), 'orders hub');
      expect(find.byType(V3OrdersPage), findsOneWidget);
      expect(controller.page, AppPage.orders);
      await _tap(tester, find.byTooltip('返回我的'), 'orders back');
      expect(controller.page, AppPage.account);
      // Gift card: the shop strip opens the sheet; closing returns to 套餐.
      controller.goToPage(AppPage.shop);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('立即兑换'), 'shop redeem strip');
      expect(find.byType(V3GiftCardPage), findsOneWidget);
      await _tap(tester, find.byTooltip('关闭'), 'gift sheet close');
      expect(find.byType(V3GiftCardPage), findsNothing,
        reason: 'gift sheet did not close');
      expect(controller.page, AppPage.shop);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('every sub-page gets back to its tab through the bottom bar', (
    tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      for (final (tab, items) in <(AppPage, List<V3NavItem>)>[
        // §13.3 test change reason: the overflow pages used to return through
        // the deleted 更多 tab; the bottom bar's source tab for them is now
        // 我的, so the loop walks the account tab instead.
        (AppPage.account, kMobileMore),
      ]) {
        for (final page in enabledNavItems(items).map((item) => item.page)) {
          controller.goToPage(page);
          await tester.pumpAndSettle();
          expect(
            find.byTooltip('返回账户'),
            findsNothing,
            reason: '${page.name} should not repeat the bottom bar',
          );
          await _tap(tester, _tab(_primaryLabel(tab)), '${tab.name} tab');
          expect(
            controller.page,
            tab,
            reason: 'bottom nav must leave ${page.name} for ${tab.name}',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}

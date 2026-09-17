import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_gift_card_page.dart';
import 'package:litchi_client/v3/pages/v3_orders_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

/// Tracks navigation issued through the shell so the test can assert on the
/// real wiring without touching [AppController]'s private page state.
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

/// The caller pins the target platform via [_onPlatform] first: Windows
/// renders the rail, Android renders the compact layout.
Future<_NavController> _pumpShell(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = _NavController();
  addTearDown(controller.disposeVisual);
  // AppScope above MaterialApp, as in `LitchiApp`: the routes a Navigator
  // builds are siblings of `home`, not descendants of it, so a scope placed
  // inside `home` is invisible to every dialog and sheet.
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.dark(), home: const V3Shell()),
    ),
  );
  await tester.pump();
  return controller;
}

/// The widget each hub page shows as sheet content.
Type _sheetType(AppPage page) => switch (page) {
  AppPage.orders => V3OrdersPage,
  AppPage.giftCard => V3GiftCardPage,
  _ => throw ArgumentError('${page.name} is not a hub sheet'),
};

/// Runs [body] with the target platform pinned, restoring it before the test
/// framework verifies that no foundation debug variable was left changed.
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
Finder _hubRow(AppPage page) => find.byKey(hubRowKey(page));
Finder _moreRow(AppPage page) => find.byKey(moreRowKey(page));

/// The bottom bar is a public Material widget, so its destinations can be
/// scoped precisely rather than by ambiguous label text.
Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

String _primaryLabel(AppPage page) => enabledNavItems(
  kMobilePrimary,
).firstWhere((item) => item.page == page).label;

void main() {
  // The invariant: every page the current panel exposes is reachable from the
  // shell. This is what the hardcoded nav lists used to violate — `orders` had
  // no inbound link at all and five pages were unreachable on compact layouts.
  final reachable = AppPage.values.where(isPageEnabled).toList();

  // 更多 is the compact overflow. Wide layouts reach the four pages behind it
  // from the rail, so the tab itself has no desktop entry point by design.
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
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            await _tap(tester, _rail(target), target.name);
          case AppPage.account:
            await _tap(tester, find.byKey(kAccountCardKey), 'account card');
          case AppPage.orders:
          case AppPage.giftCard:
            // No dedicated rail entry: identity card, then the account hub row.
            await _tap(tester, find.byKey(kAccountCardKey), 'account card');
            await _tap(tester, _hubRow(target), target.name);
            // These two are sheets rather than pages, so reaching them is
            // the sheet appearing — and the page underneath staying put is
            // the point of the change, not an incidental detail.
            expect(
              find.byType(_sheetType(target)),
              findsOneWidget,
              reason: '${target.name} must open from the account hub',
            );
            expect(
              controller.page,
              AppPage.account,
              reason: '${target.name} is a modal and must not navigate',
            );
            return;
          case AppPage.more:
            // Filtered out of this loop; the switch is total all the same.
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
          case AppPage.more:
            await _tap(tester, _tab(_primaryLabel(target)), target.name);
          case AppPage.orders:
          case AppPage.giftCard:
            // Account business lives in the account page's hub, as a sheet.
            await _tap(
              tester,
              _tab(_primaryLabel(AppPage.account)),
              'account tab',
            );
            await _tap(tester, _hubRow(target), target.name);
            expect(
              find.byType(_sheetType(target)),
              findsOneWidget,
              reason: '${target.name} must open from the account hub',
            );
            expect(
              controller.page,
              AppPage.account,
              reason: '${target.name} is a modal and must not navigate',
            );
            return;
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            // Neither a tab nor an account concern: the 更多 overflow.
            await _tap(tester, _tab(_primaryLabel(AppPage.more)), 'more tab');
            await _tap(tester, _moreRow(target), target.name);
        }

        expect(
          controller.page,
          target,
          reason: '${target.name} must be reachable on a 390dp layout',
        );
      });
    });
  }

  test('every enabled page is declared in the nav model', () {
    // Each surface is checked on its own: a page may legitimately appear on
    // both the compact and the desktop surface, but never twice on one.
    for (final surface in <(String, List<V3NavItem>)>[
      ('kMobilePrimary', kMobilePrimary),
      ('kMobileHub', kMobileHub),
      ('kMobileMore', kMobileMore),
      ('kDesktopRail', [...kDesktopRail, kRailSettings]),
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
      ...kMobileHub.map((item) => item.page),
      ...kDesktopRail.map((item) => item.page),
      kRailSettings.page,
    };
    for (final page in AppPage.values) {
      expect(
        declared.contains(page),
        isTrue,
        reason: '${page.name} is missing from the nav model entirely',
      );
    }
  });

  testWidgets('hub pages highlight the account tab rather than nothing', (
    tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      final accountIndex = enabledNavItems(
        kMobilePrimary,
      ).indexWhere((item) => item.page == AppPage.account);
      expect(accountIndex, isNonNegative, reason: '账户 must be a primary tab');

      for (final page in enabledNavItems(kMobileHub).map((item) => item.page)) {
        controller.goToPage(page);
        await tester.pumpAndSettle();
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(
          bar.selectedIndex,
          accountIndex,
          reason: '${page.name} should read as an account sub-page',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  // The counterpart for the overflow: 流量, 邀请, 工单 and 设置 are not account
  // business, so they must not light up 账户.
  testWidgets('overflow pages highlight the 更多 tab', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      final moreIndex = enabledNavItems(
        kMobilePrimary,
      ).indexWhere((item) => item.page == AppPage.more);
      expect(moreIndex, isNonNegative, reason: '更多 must be a primary tab');

      for (final page in enabledNavItems(
        kMobileMore,
      ).map((item) => item.page)) {
        controller.goToPage(page);
        await tester.pumpAndSettle();
        final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(
          bar.selectedIndex,
          moreIndex,
          reason: '${page.name} should read as a 更多 sub-page',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  // The wallet used to be one 资金中心 sheet holding every money action at
  // once, reached by tapping a balance card that did nothing else. The three
  // verbs are buttons on the account page now, and each opens its own dialog:
  // a tap on 充值 must not also offer 提现.
  testWidgets('each wallet action opens its own dialog', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();

      expect(
        find.text('账户余额'),
        findsOneWidget,
        reason: 'the balance must be on the account page, not behind a tap',
      );

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
        // Exactly one dialog at a time: opening 充值 must not bring the other
        // two actions along with it.
        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason: '$label stacked more than one dialog',
        );
        await _tap(tester, find.byTooltip('关闭'), '$label close button');
        expect(
          find.byType(Dialog),
          findsNothing,
          reason: '$label did not close',
        );
        expect(controller.page, AppPage.account);
      }
      expect(tester.takeException(), isNull);
    });
  });

  // The complaint that started this: 点了钱包是不能返回的. A hub sheet is
  // dismissible rather than navigable, so the account page it was opened from
  // is still there and closing the sheet is all it takes to see it again.
  testWidgets('a hub sheet closes back onto the account page', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();

      for (final page in enabledNavItems(kMobileHub).map((item) => item.page)) {
        await _tap(tester, _hubRow(page), page.name);
        expect(find.byType(_sheetType(page)), findsOneWidget);

        await _tap(tester, find.byTooltip('关闭'), 'the sheet close button');
        expect(
          find.byType(_sheetType(page)),
          findsNothing,
          reason: '${page.name} did not close',
        );
        expect(
          controller.page,
          AppPage.account,
          reason: 'closing ${page.name} must land back on 账户',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  // The highlight asserted above is only honest if the page also offers a way
  // back to the tab it claims the user is on. Every sub-page used to carry its
  // own 返回账户 button for this, which the user reported as redundant — the
  // bottom bar already does the job, and it is on screen the whole time.
  testWidgets('every sub-page gets back to its tab through the bottom bar', (
    tester,
  ) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      for (final (tab, items) in <(AppPage, List<V3NavItem>)>[
        (AppPage.account, kMobileHub),
        (AppPage.more, kMobileMore),
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
            reason: 'the bottom bar did not leave ${page.name} for ${tab.name}',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}

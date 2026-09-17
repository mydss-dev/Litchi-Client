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

Future<_NavController> _pump(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _NavController();
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(controller: controller,
    child: MaterialApp(theme: V3Theme.dark(), home: const V3Shell())));
  await tester.pump();
  return controller;
}

Future<void> _onPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try { await body(); } finally { debugDefaultTargetPlatformOverride = null; }
}

Finder _rail(AppPage page) => find.byKey(railItemKey(page));
Finder _moreRow(AppPage page) => find.byKey(moreRowKey(page));
Finder _hub(AppPage page) => find.text(kMobileHub.firstWhere((item) => item.page == page).label);
Finder _tab(AppPage page) {
  final label = enabledNavItems(kMobilePrimary).firstWhere((item) => item.page == page).label;
  return find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
}

Type _sheetType(AppPage page) => switch (page) {
  AppPage.orders => V3OrdersPage,
  AppPage.giftCard => V3GiftCardPage,
  _ => throw ArgumentError('${page.name} is not an account sheet'),
};

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

void main() {
  final reachable = AppPage.values.where(isPageEnabled).toList();
  final desktopReachable = reachable.where((page) => page != AppPage.more);

  for (final target in desktopReachable) {
    testWidgets('desktop can reach ${target.name}', (tester) async {
      await _onPlatform(TargetPlatform.windows, () async {
        final c = await _pump(tester, _desktop);
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
            await _tap(tester, find.byKey(kAccountCardKey), 'account card');
            await _tap(tester, _hub(target), target.name);
            expect(find.byType(_sheetType(target)), findsOneWidget);
            expect(c.page, AppPage.account);
            return;
          case AppPage.more:
            return;
        }
        expect(c.page, target);
      });
    });
  }

  for (final target in reachable) {
    testWidgets('mobile can reach ${target.name}', (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final c = await _pump(tester, _mobile);
        await tester.pumpAndSettle();
        switch (target) {
          case AppPage.dashboard:
          case AppPage.nodes:
          case AppPage.shop:
          case AppPage.account:
          case AppPage.more:
            await _tap(tester, _tab(target), target.name);
          case AppPage.orders:
          case AppPage.giftCard:
            await _tap(tester, _tab(AppPage.account), 'account tab');
            await _tap(tester, _hub(target), target.name);
            expect(find.byType(_sheetType(target)), findsOneWidget);
            expect(c.page, AppPage.account);
            return;
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            await _tap(tester, _tab(AppPage.more), 'more tab');
            await _tap(tester, _moreRow(target), target.name);
        }
        expect(c.page, target);
      });
    });
  }

  test('all enabled pages occur in the nav model without duplicate entries', () {
    for (final items in <List<V3NavItem>>[
      kMobilePrimary, kMobileHub, kMobileMore, [...kDesktopRail, kRailSettings],
    ]) {
      final seen = <AppPage>{};
      for (final item in items) {
        expect(seen.add(item.page), isTrue, reason: '${item.page.name} is duplicated');
      }
    }
    final declared = <AppPage>{
      ...kMobilePrimary.map((item) => item.page),
      ...kMobileHub.map((item) => item.page),
      ...kMobileMore.map((item) => item.page),
      ...kDesktopRail.map((item) => item.page),
      kRailSettings.page,
    };
    for (final page in AppPage.values) {
      expect(declared.contains(page), isTrue, reason: '${page.name} missing from nav model');
    }
  });

  testWidgets('account subpages highlight the account tab', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final c = await _pump(tester, _mobile);
      final accountIndex = enabledNavItems(kMobilePrimary)
          .indexWhere((item) => item.page == AppPage.account);
      for (final item in enabledNavItems(kMobileHub)) {
        c.goToPage(item.page);
        await tester.pumpAndSettle();
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          accountIndex);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('overflow pages highlight the more tab', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final c = await _pump(tester, _mobile);
      final moreIndex = enabledNavItems(kMobilePrimary)
          .indexWhere((item) => item.page == AppPage.more);
      for (final item in enabledNavItems(kMobileMore)) {
        c.goToPage(item.page);
        await tester.pumpAndSettle();
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          moreIndex);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('wallet is expandable; each operation opens only its own dialog', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final c = await _pump(tester, _mobile);
      c.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      expect(find.text('账户余额'), findsOneWidget);
      await _tap(tester, find.text('我的钱包'), 'wallet expansion');
      for (final (label, title) in <(String, String)>[
        ('充值', '充值余额'),
        ('提现', '申请提现'),
        ('划转', '佣金转余额'),
      ]) {
        await _tap(tester, find.text(label), label);
        expect(find.text(title), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        await _tap(tester, find.byTooltip('关闭'), 'close $label');
        expect(find.byType(Dialog), findsNothing);
        expect(c.page, AppPage.account);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('account sheets close without leaving the account', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final c = await _pump(tester, _mobile);
      c.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      for (final page in enabledNavItems(kMobileHub).map((item) => item.page)) {
        await _tap(tester, _hub(page), page.name);
        expect(find.byType(_sheetType(page)), findsOneWidget);
        await _tap(tester, find.byTooltip('关闭'), 'sheet close');
        expect(find.byType(_sheetType(page)), findsNothing);
        expect(c.page, AppPage.account);
      }
    });
  });

  testWidgets('secondary pages have no redundant return-to-account button', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final c = await _pump(tester, _mobile);
      for (final (tab, items) in <(AppPage, List<V3NavItem>)>[
        (AppPage.account, kMobileHub),
        (AppPage.more, kMobileMore),
      ]) {
        for (final item in enabledNavItems(items)) {
          c.goToPage(item.page);
          await tester.pumpAndSettle();
          expect(find.byTooltip('返回账户'), findsNothing);
          await _tap(tester, _tab(tab), '${tab.name} tab');
          expect(c.page, tab);
        }
      }
    });
  });
}

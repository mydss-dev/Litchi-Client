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
  await tester.pumpWidget(AppScope(controller: controller,
    child: MaterialApp(
      theme: V3Theme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const V3Shell())));
  await tester.pump();
  return controller;
}

Type _sheetType(AppPage page) => switch (page) {
  AppPage.orders => V3OrdersPage,
  AppPage.giftCard => V3GiftCardPage,
  _ => throw ArgumentError('${page.name} is not an account sheet'),
};

Future<void> _onPlatform(TargetPlatform platform,
    Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try { await body(); } finally { debugDefaultTargetPlatformOverride = null; }
}

Finder _rail(AppPage page) => find.byKey(railItemKey(page));
Finder _hubRow(AppPage page) => find.byKey(hubRowKey(page));
Finder _moreRow(AppPage page) => find.byKey(moreRowKey(page));
Finder _tab(String label) => find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label));

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

String _primaryLabel(AppPage page) {
  // Return the English label for mobile primary nav items.
  // This matches the default AppLocalizations used in tests.
  return switch (page) {
    AppPage.dashboard => 'Connection',
    AppPage.nodes => 'Nodes',
    AppPage.shop => 'Plans',
    AppPage.account => 'Account',
    AppPage.more => 'More',
    _ => page.name,
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
            await _tap(tester, _hubRow(target), target.name);
            expect(find.byType(_sheetType(target)), findsOneWidget,
              reason: '${target.name} must open from account');
            expect(controller.page, AppPage.account,
              reason: '${target.name} should not replace the account page');
            return;
          case AppPage.more:
            return;
        }
        expect(controller.page, target,
          reason: '${target.name} must be reachable from the desktop rail');
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
            await _tap(tester, _tab(_primaryLabel(AppPage.account)), 'account tab');
            await _tap(tester, _hubRow(target), target.name);
            expect(find.byType(_sheetType(target)), findsOneWidget);
            expect(controller.page, AppPage.account,
              reason: '${target.name} is an account modal');
            return;
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            await _tap(tester, _tab(_primaryLabel(AppPage.more)), 'more tab');
            await _tap(tester, _moreRow(target), target.name);
        }
        expect(controller.page, target,
          reason: '${target.name} must be reachable at 390dp');
      });
    });
  }

  test('every enabled page is declared in the nav model', () {
    for (final surface in <(String, List<V3NavItem>)>[
      ('kMobilePrimary', kMobilePrimary),
      ('kMobileHub', kMobileHub),
      ('kMobileMore', kMobileMore),
      ('kDesktopRail', [...kDesktopRail, kRailSettings]),
    ]) {
      final (name, items) = surface;
      final seen = <AppPage>{};
      for (final item in items) {
        expect(seen.add(item.page), isTrue,
          reason: '${item.page.name} is declared twice in $name');
      }
    }
    final declared = {
      ...kMobilePrimary.map((item) => item.page),
      ...kMobileHub.map((item) => item.page),
      ...kDesktopRail.map((item) => item.page),
      kRailSettings.page,
    };
    for (final page in AppPage.values) {
      expect(declared.contains(page), isTrue,
        reason: '${page.name} is missing from the nav model entirely');
    }
  });

  testWidgets('hub pages highlight the account tab rather than nothing',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      final accountIndex = enabledNavItems(kMobilePrimary)
          .indexWhere((item) => item.page == AppPage.account);
      expect(accountIndex, isNonNegative);
      for (final page in enabledNavItems(kMobileHub).map((item) => item.page)) {
        controller.goToPage(page);
        await tester.pumpAndSettle();
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          accountIndex, reason: '${page.name} should highlight account');
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('overflow pages highlight the 更多 tab', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      final moreIndex = enabledNavItems(kMobilePrimary)
          .indexWhere((item) => item.page == AppPage.more);
      expect(moreIndex, isNonNegative);
      for (final page in enabledNavItems(kMobileMore).map((item) => item.page)) {
        controller.goToPage(page);
        await tester.pumpAndSettle();
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
          moreIndex, reason: '${page.name} should highlight 更多');
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('inline wallet actions open their own dialogs and remain visible',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      expect(find.text('账户余额'), findsOneWidget);
      expect(find.text('可提现佣金'), findsOneWidget,
        reason: 'commission must be visible without opening a wallet sheet');
      expect(find.text('我的钱包'), findsNothing,
        reason: 'restored layout uses direct wallet controls');
      const actionTitles = ['充值余额', '申请提现', '佣金转余额'];
      for (final (label, dialogTitle) in <(String, String)>[
        ('充值', '充值余额'),
        ('提现', '申请提现'),
        ('划转', '佣金转余额'),
      ]) {
        await _tap(tester, find.text(label), label);
        expect(find.text(dialogTitle), findsOneWidget,
          reason: '$label must open its own dialog');
        for (final other in actionTitles.where((title) => title != dialogTitle)) {
          expect(find.text(other), findsNothing,
            reason: '$label must not open unrelated dialogs');
        }
        final activeDialog = find.ancestor(
          of: find.text(dialogTitle), matching: find.byType(Dialog)).first;
        expect(activeDialog, findsOneWidget);
        await _tap(tester, find.descendant(
          of: activeDialog, matching: find.byTooltip('关闭')),
          '$label dialog close');
        expect(find.text(dialogTitle), findsNothing);
        expect(find.text('可提现佣金'), findsOneWidget,
          reason: 'closing dialog returns to visible wallet area');
        expect(controller.page, AppPage.account);
      }
      expect(find.text('我的服务'), findsOneWidget);
      expect(controller.page, AppPage.account);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a hub sheet closes back onto the account page', (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      for (final page in enabledNavItems(kMobileHub).map((item) => item.page)) {
        await _tap(tester, _hubRow(page), page.name);
        expect(find.byType(_sheetType(page)), findsOneWidget);
        await _tap(tester, find.byTooltip('关闭'), 'account sheet close');
        expect(find.byType(_sheetType(page)), findsNothing,
          reason: '${page.name} did not close');
        expect(controller.page, AppPage.account);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('every sub-page gets back to its tab through the bottom bar',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, _mobile);
      for (final (tab, items) in <(AppPage, List<V3NavItem>)>[
        (AppPage.account, kMobileHub),
        (AppPage.more, kMobileMore),
      ]) {
        for (final page in enabledNavItems(items).map((item) => item.page)) {
          controller.goToPage(page);
          await tester.pumpAndSettle();
          expect(find.byTooltip('返回账户'), findsNothing,
            reason: '${page.name} should not repeat the bottom bar');
          await _tap(tester, _tab(_primaryLabel(tab)), '${tab.name} tab');
          expect(controller.page, tab,
            reason: 'bottom nav must leave ${page.name} for ${tab.name}');
        }
      }
      expect(tester.takeException(), isNull);
    });
  });
}

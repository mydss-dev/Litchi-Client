import 'package:ios26_bottom_navigationbar/ios26_bottom_navigationbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoListSection;
import 'package:forui/forui.dart' show FCard, FAvatar;
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_gift_card_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_nav_island.dart';

import 'v3_visual_fixture.dart';

class _NavController extends VisualV3Controller {
  _NavController({this.noPlan = false}) : super(AppPage.dashboard);
  final bool noPlan;
  AppPage current = AppPage.dashboard;

  @override
  AppPage get page => current;

  @override
  void goToPage(AppPage page) {
    if (!isPageEnabled(page)) return;
    current = page;
    notifyListeners();
  }

  @override
  bool get hasPlan => !noPlan;

  @override
  bool get hasConfirmedNoPlan => noPlan;
}

Future<_NavController> _pumpShell(WidgetTester tester, Size size,
    {bool noPlan = false}) async {
  // Flutter 3.50 needs the actual test view dimensions pinned, otherwise
  // MediaQuery stays at its 800x600 default despite setSurfaceSize.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final controller = _NavController(noPlan: noPlan);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: V3Theme.dark(),
      home: const V3Shell(),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _onPlatform(TargetPlatform platform,
    Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Android iOS26 navigation shows four labels and all routes remain functional',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      expect(find.byType(V3NavIsland), findsOneWidget);
      expect(find.byType(IOS26BottomNavigationBar), findsOneWidget);
      final dock = find.byType(IOS26BottomNavigationBar);
      for (final label in ['连接', '节点', '套餐', '我的']) {
        expect(find.descendant(of: dock, matching: find.text(label)), findsOneWidget);
      }
      expect(tester.getSize(dock).height, 62);
      expect(tester.getRect(dock).bottom, lessThanOrEqualTo(844 - 6));
      const destinations = [
        AppPage.dashboard, AppPage.nodes, AppPage.shop, AppPage.account,
      ];
      for (final page in [AppPage.nodes, AppPage.shop, AppPage.account,
          AppPage.dashboard]) {
        final tabIndex = destinations.indexOf(page);
        final tabs = find.descendant(
          of: find.byType(IOS26BottomNavigationBar),
          matching: find.byType(GestureDetector),
        );
        expect(tabs, findsNWidgets(4));
        await _tap(tester, tabs.at(tabIndex));
        expect(controller.page, page);
        expect(find.byType(IOS26BottomNavigationBar), findsOneWidget);
      }
    });
  });

  for (final page in [
    AppPage.orders,
    AppPage.traffic,
    AppPage.invite,
    AppPage.tickets,
    AppPage.settings,
    AppPage.more,
  ]) {
    testWidgets('Android secondary '+page.name+' has back and no bottom bar',
        (tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        final controller = await _pumpShell(tester, const Size(390, 844));
        controller.goToPage(page);
        await tester.pumpAndSettle();
        expect(find.byType(V3NavIsland), findsNothing);
        final back = find.byKey(const ValueKey('v3-mobile-secondary-back'));
        expect(back, findsOneWidget);
        await _tap(tester, back);
        expect(controller.page, AppPage.account);
        expect(find.byType(V3NavIsland), findsOneWidget);
      });
    });
  }

  testWidgets('Android account services open wallet as a separate page',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      // Wallet totals and money movement are no longer inline on Account.
      expect(find.text('账户余额'), findsNothing);
      await _tap(tester, find.text('我的钱包'));
      expect(find.text('账户余额'), findsWidgets);
      expect(find.byType(V3NavIsland), findsNothing);
      await _tap(tester,
          find.byKey(const ValueKey('v3-mobile-secondary-back')));
      expect(controller.page, AppPage.account);
      expect(find.byType(V3NavIsland), findsOneWidget);
    });
  });

  testWidgets('Android account management contains sensitive settings',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      expect(find.text('修改密码'), findsNothing);
      await _tap(tester, find.text('管理账户'));
      expect(find.text('修改密码'), findsOneWidget);
      expect(find.text('Telegram 绑定'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);
    });
  });

  testWidgets('Android account services restores vertical list with wallet and settings',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      final orders = find.byKey(hubRowKey(AppPage.orders));
      final wallet = find.byKey(
          const ValueKey('v3-account-wallet-service'));
      final settings = find.byKey(hubRowKey(AppPage.settings));
      expect(find.text('账户服务'), findsOneWidget);
      expect(find.text('5 项功能'), findsOneWidget);
      expect(find.byKey(hubRowKey(AppPage.traffic)), findsNothing);
      expect(find.text('流量用量'), findsNothing);
      expect(find.byType(CupertinoListSection), findsOneWidget);
      expect(find.byType(FCard), findsNWidgets(2));
      expect(find.byKey(const ValueKey('v3-account-merged-card')),
          findsOneWidget);
      expect(find.byType(FAvatar), findsOneWidget);
      expect(orders, findsOneWidget);
      expect(wallet, findsOneWidget);
      expect(settings, findsOneWidget);
      expect(tester.getRect(wallet).top,
          lessThan(tester.getRect(orders).top));
      expect(find.text('工单支持'), findsOneWidget);
      expect(find.text('帮助与工单'), findsNothing);
      expect(tester.getRect(settings).top,
          greaterThan(tester.getRect(wallet).top));

      await _tap(tester, settings);
      expect(controller.page, AppPage.settings);
      expect(find.byType(V3NavIsland), findsNothing);
      await _tap(tester,
          find.byKey(const ValueKey('v3-mobile-secondary-back')));
      expect(controller.page, AppPage.account);
    });
  });

  testWidgets('Android card opens usage; renewal is not an account service',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('v3-account-renew-service')), findsNothing);
      expect(find.text('续费'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('v3-mobile-plan-card')));
      expect(controller.page, AppPage.traffic);
      expect(find.text('套餐'), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-mobile-plan-card')), findsNothing);
      expect(find.text('套餐流量'), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-usage-renew')), findsOneWidget);
      await _tap(tester, find.byKey(
          const ValueKey('v3-mobile-secondary-back')));
      expect(controller.page, AppPage.account);
    });
  });

  testWidgets('Android order history is reachable from account services',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.account);
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(hubRowKey(AppPage.orders)));
      expect(controller.page, AppPage.orders);
      expect(find.byType(V3NavIsland), findsNothing);
      await _tap(tester, find.byKey(
          const ValueKey('v3-mobile-secondary-back')));
      expect(controller.page, AppPage.account);
    });
  });

  testWidgets('gift-card entry is hidden for accounts with a plan',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844));
      controller.goToPage(AppPage.shop);
      await tester.pumpAndSettle();
      expect(find.text('立即兑换'), findsNothing);
    });
  });

  testWidgets('gift-card entry opens for confirmed no-plan account',
      (tester) async {
    await _onPlatform(TargetPlatform.android, () async {
      final controller = await _pumpShell(tester, const Size(390, 844),
          noPlan: true);
      controller.goToPage(AppPage.shop);
      await tester.pumpAndSettle();
      await _tap(tester, find.text('立即兑换'));
      expect(find.byType(V3GiftCardPage), findsOneWidget);
      expect(controller.page, AppPage.shop);
      await _tap(tester, find.byTooltip('关闭'));
      expect(find.byType(V3GiftCardPage), findsNothing);
    });
  });

  testWidgets('Windows desktop rail remains usable', (tester) async {
    await _onPlatform(TargetPlatform.windows, () async {
      final controller = await _pumpShell(tester, const Size(900, 700));
      await _tap(tester, find.byKey(railItemKey(AppPage.nodes)));
      expect(controller.page, AppPage.nodes);
      await _tap(tester, find.byKey(railItemKey(AppPage.shop)));
      expect(controller.page, AppPage.shop);
      expect(find.byType(V3NavIsland), findsNothing);
    });
  });
}

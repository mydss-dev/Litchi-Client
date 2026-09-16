import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
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
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.dark(),
      home: AppScope(controller: controller, child: const V3Shell()),
    ),
  );
  await tester.pump();
  return controller;
}

/// Runs [body] with the target platform pinned, restoring it before the test
/// framework verifies that no foundation debug variable was left changed.
Future<void> _onPlatform(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Finder _rail(AppPage page) => find.byKey(railItemKey(page));
Finder _hubRow(AppPage page) => find.byKey(hubRowKey(page));

/// The bottom bar is a public Material widget, so its destinations can be
/// scoped precisely rather than by ambiguous label text.
Finder _tab(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

Future<void> _tap(WidgetTester tester, Finder finder, String what) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'tapping $what threw');
}

String _primaryLabel(AppPage page) =>
    enabledNavItems(kMobilePrimary).firstWhere((item) => item.page == page).label;

void main() {
  // The invariant: every page the current panel exposes is reachable from the
  // shell. This is what the hardcoded nav lists used to violate — `orders` had
  // no inbound link at all and five pages were unreachable on compact layouts.
  final reachable = AppPage.values.where(isPageEnabled).toList();

  for (final target in reachable) {
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
          case AppPage.wallet:
          case AppPage.orders:
            // No dedicated rail entry: identity card, then the account hub row.
            await _tap(tester, find.byKey(kAccountCardKey), 'account card');
            await _tap(tester, _hubRow(target), target.name);
        }

        expect(
          controller.page,
          target,
          reason: '${target.name} must be reachable from the desktop rail',
        );
      });
    });

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
          case AppPage.wallet:
          case AppPage.orders:
          case AppPage.traffic:
          case AppPage.invite:
          case AppPage.tickets:
          case AppPage.settings:
            // Secondary pages live in the account hub on compact layouts.
            await _tap(tester, _tab(_primaryLabel(AppPage.account)), 'account tab');
            await _tap(tester, _hubRow(target), target.name);
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
}

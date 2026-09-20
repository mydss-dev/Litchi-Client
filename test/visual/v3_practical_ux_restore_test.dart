import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/pages/v3_settings_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_logout_confirmation.dart';

import 'v3_visual_fixture.dart';

class _NoPlanFixture extends VisualV3Controller {
  _NoPlanFixture() : super(AppPage.dashboard);
  @override
  bool get hasPlan => false;
}

class _RefreshFixture extends VisualV3Controller {
  _RefreshFixture(super.page);
  int refreshCount = 0;

  @override
  Future<void> refreshData() async {
    refreshCount++;
  }
}

void main() {
  testWidgets('log out needs an explicit destructive confirmation', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          confirmed = await showV3LogoutConfirmation(context);
        },
        child: const Text('Open confirmation'),
      ))),
    ));

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('确认退出登录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v3-logout-cancel')));
    await tester.pumpAndSettle();
    expect(confirmed, false);

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v3-logout-confirm')));
    await tester.pumpAndSettle();
    expect(confirmed, true);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    testWidgets('confirmed no-plan state replaces only connection cards at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = _NoPlanFixture();
      addTearDown(fixture.disposeVisual);
      await tester.pumpWidget(AppScope(
        controller: fixture,
        child: MaterialApp(theme: V3Theme.light(),
          home: const Scaffold(body: V3DashboardPage())),
      ));
      await tester.pump();
      expect(find.text('当前没有可用套餐'), findsOneWidget);
      expect(find.byKey(kConnectActionCardKey), findsNothing);
      expect(find.byKey(kCurrentNodeCardKey), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('desktop-only settings are hidden on mobile and Linux', () {
    expect(v3HasDesktopSystemTools(TargetPlatform.windows), true);
    expect(v3HasDesktopSystemTools(TargetPlatform.macOS), true);
    expect(v3HasDesktopSystemTools(TargetPlatform.android), false);
    expect(v3HasDesktopSystemTools(TargetPlatform.iOS), false);
    expect(v3HasDesktopSystemTools(TargetPlatform.linux), false);
  });

  test('mobile refresh excludes the informational nodes page', () {
    for (final page in [AppPage.dashboard, AppPage.account,
      AppPage.invite, AppPage.traffic]) {
      expect(v3SupportsMobileRefresh(page), true);
    }
    for (final page in [AppPage.nodes, AppPage.shop, AppPage.settings]) {
      expect(v3SupportsMobileRefresh(page), false);
    }
  });

  testWidgets('Android home exposes pull-to-refresh and calls refreshData',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _RefreshFixture(AppPage.dashboard);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(), home: const V3Shell()),
    ));
    await tester.pump();
    final indicator = find.byKey(const Key('v3-mobile-refresh'));
    expect(indicator, findsOneWidget);
    await tester.widget<RefreshIndicator>(indicator).onRefresh();
    expect(controller.refreshCount, 1);
    expect(tester.takeException(), isNull);
  });
}

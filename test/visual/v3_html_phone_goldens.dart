import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/ui/v3_nav_island.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _NavigableVisualController extends VisualV3Controller {
  _NavigableVisualController(AppPage initial)
      : _current = initial, super(initial);

  AppPage _current;
  @override
  AppPage get page => _current;

  @override
  void goToPage(AppPage next) {
    _current = next;
    notifyListeners();
  }
}


void main() {
  setUpAll(() async {
    final file = File('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');
    if (!file.existsSync()) return;
    final data = ByteData.sublistView(await file.readAsBytes());
    for (final family in <String>[
      'Segoe UI',
      'Segoe UI Variable',
      'SF Pro Text',
      'Microsoft YaHei UI',
      'Roboto',
      'Noto Sans',
      'Noto Sans CJK SC',
    ]) {
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
    }
  });

  for (final (page, name) in <(AppPage, String)>[
    (AppPage.dashboard, '01_html_connect'),
    (AppPage.nodes, '02_html_nodes'),
    (AppPage.shop, '03_html_plans'),
    (AppPage.account, '04_html_account'),
    (AppPage.orders, '05_html_orders'),
    (AppPage.traffic, '06_html_traffic'),
    (AppPage.tickets, '07_html_tickets'),
    (AppPage.invite, '08_html_invite'),
    (AppPage.settings, '09_html_settings'),
  ]) {
    testWidgets('HTML faithful Android phone $name screenshot',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });
      final controller = _NavigableVisualController(page);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('html-phone-capture'),
        child: AppScope(
          controller: controller,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh'),
            theme: V3Theme.light(),
            darkTheme: V3Theme.dark(),
            themeMode: ThemeMode.dark,
            home: const V3Shell(),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final secondary = page != AppPage.dashboard &&
          page != AppPage.nodes &&
          page != AppPage.shop &&
          page != AppPage.account;
      if (secondary) {
        // Every subpage has a visible back affordance and no primary tab bar.
        expect(find.byType(V3NavIsland), findsNothing);
        expect(find.byKey(const ValueKey('v3-mobile-secondary-back')), findsOneWidget);
      } else {
        expect(find.byType(V3NavIsland), findsOneWidget);
      }
      await expectLater(
        find.byKey(const ValueKey('html-phone-capture')),
        matchesGoldenFile('html_goldens/$name.png'),
      );
      if (secondary) {
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(controller.page, AppPage.account,
          reason: 'Android back must return to Account from $name');
      }
    });
  }
}

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_account_page.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

import 'v3_visual_fixture.dart';

void main() {
  for (final (page, title, subtitle) in <(Widget, String, String)>[
    (const V3DashboardPage(), '连接', '连接状态与路由模式'),
    (const V3NodesPage(), '节点', '4 个节点 · 2 个地区'),
    (const V3ShopPage(), '套餐', '选择适合你的方案'),
    (const V3AccountPage(), '我的', '账户与订阅管理'),
  ]) {
    testWidgets('mobile $title uses the shared primary title layout', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.dashboard);
      addTearDown(controller.disposeVisual);

      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(),
          home: Scaffold(body: page),
        ),
      ));
      await tester.pump();
      final header = find.byType(V3PrimaryPageHeader);
      expect(header, findsOneWidget);
      final titleFinder = find.descendant(
        of: header, matching: find.text(title));
      final subtitleFinder = find.descendant(
        of: header, matching: find.text(subtitle));
      expect(titleFinder, findsOneWidget);
      expect(subtitleFinder, findsOneWidget);
      expect(tester.widget<Text>(titleFinder).style?.fontSize, 28);
      expect(tester.widget<Text>(subtitleFinder).style?.fontSize, 12);
      expect(tester.getRect(titleFinder).bottom,
        lessThan(tester.getRect(subtitleFinder).top));
      expect(tester.takeException(), isNull);
    });
  }
}

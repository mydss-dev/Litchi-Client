import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/shared/theme/app_icons.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

import 'v3_visual_fixture.dart';

void main() {
  testWidgets('plans and nodes reuse identical mobile filters at 320dp',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final shop = VisualV3Controller(AppPage.shop);
    final nodes = VisualV3Controller(AppPage.nodes);
    addTearDown(shop.disposeVisual);
    addTearDown(nodes.disposeVisual);

    Future<void> show(AppController controller, Widget page) async {
      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(),
          home: Scaffold(body: page)),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await show(shop, const V3ShopPage());
    expect(find.byType(V3MobileFilterChip), findsNWidgets(3));
    final shopAll = find.byKey(const ValueKey('shop-filter-all'));
    expect(tester.widget<V3MobileFilterChip>(shopAll).selected, isTrue);
    final shopMaterial = tester.widget<Material>(
      find.descendant(of: shopAll, matching: find.byType(Material)).first);
    expect(shopMaterial.color, V3Palette.light.night);
    await tester.tap(find.byKey(const ValueKey('shop-filter-recurring')));
    await tester.pump();
    expect(tester.widget<V3MobileFilterChip>(
      find.byKey(const ValueKey('shop-filter-recurring'))).selected, isTrue);

    await show(nodes, const V3NodesPage());
    // The node page keeps one round filter button in the search row; the
    // region choices open as a popup menu instead of a permanent chip row.
    final nodeFilter = find.byKey(const ValueKey('v3-node-filter-button'));
    expect(nodeFilter, findsOneWidget);
    expect(tester.getSize(nodeFilter).height, greaterThanOrEqualTo(44));
    await tester.tap(nodeFilter);
    await tester.pumpAndSettle();
    final nodeAll = find.byKey(const ValueKey('v3-map-country-all'));
    expect(nodeAll, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v3-region-NodeRegion.asia')));
    await tester.pumpAndSettle();
    // Re-open: the checked item marks the active filter.
    await tester.tap(nodeFilter);
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.byKey(const ValueKey('v3-region-NodeRegion.asia')),
      matching: find.byIcon(AppIcons.check)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v3-region-NodeRegion.asia')));
    await tester.pumpAndSettle();
    final search = find.byType(TextField);
    await tester.enterText(search, 'impossible-node-match');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的节点'), findsOneWidget);
    final clearSearch = find.byKey(const ValueKey('v3-node-clear-search'));
    await tester.tap(clearSearch);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    await tester.tap(nodeFilter);
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: find.byKey(const ValueKey('v3-region-NodeRegion.asia')),
      matching: find.byIcon(AppIcons.check)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v3-region-NodeRegion.asia')));
    await tester.pumpAndSettle();
    await tester.enterText(search, 'impossible-node-match');
    await tester.pumpAndSettle();
    final reset = find.text('清除筛选');
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    await tester.tap(nodeFilter);
    await tester.pumpAndSettle();
    expect(find.descendant(
      of: nodeAll, matching: find.byIcon(AppIcons.check)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

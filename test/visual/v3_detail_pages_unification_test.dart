import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_account_page.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

import 'v3_visual_fixture.dart';

Future<void> pumpPage(
  WidgetTester tester,
  Widget page,
  AppPage selected, {
  required Size size,
  required ThemeMode theme,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = VisualV3Controller(selected);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.light(),
      darkTheme: V3Theme.dark(),
      themeMode: theme,
      home: AppScope(
        controller: controller,
        child: Scaffold(body: page),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(900, 700), const Size(360, 800)]) {
      testWidgets('node overview is one read-only list at $size $theme', (
        tester,
      ) async {
        await pumpPage(
          tester,
          const V3NodesPage(),
          AppPage.nodes,
          size: size,
          theme: theme,
        );
        final node = find.byKey(const ValueKey('v3-node-overview-jp-01'));
        expect(node, findsOneWidget);
        final list = find.ancestor(of: node, matching: find.byType(V3Panel));
        expect(list, findsOneWidget);
        expect(
          find.descendant(of: list, matching: find.byType(Divider)),
          findsNWidgets(3),
        );
        expect(
          find.ancestor(of: node, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'compact account retains services and actions at $size $theme',
        (tester) async {
          await pumpPage(
            tester,
            const V3AccountPage(),
            AppPage.account,
            size: size,
            theme: theme,
          );
          expect(find.text('我的账户'), findsOneWidget);
          expect(find.text('我的服务'), findsOneWidget);
          expect(find.text('账户偏好'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('plan filters have a touch target and a lychee selected state', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const V3ShopPage(),
      AppPage.shop,
      size: const Size(360, 800),
      theme: ThemeMode.light,
    );
    final all = find.byKey(const ValueKey('v3-plan-category-all'));
    expect(all, findsOneWidget);
    expect(tester.getSize(all).height, greaterThanOrEqualTo(44));
    final selected = tester.widget<AnimatedContainer>(
      find.descendant(of: all, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (selected.decoration as BoxDecoration).color,
      V3Palette.light.lycheeSoft,
    );
    await tester.tap(find.byKey(const ValueKey('v3-plan-category-dataPack')));
    await tester.pumpAndSettle();
    expect(find.text('300G 流量包'), findsOneWidget);
    expect(find.text('Litchi Prime · 1024G'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

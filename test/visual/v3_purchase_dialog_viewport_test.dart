import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

void main() {
  for (final size in [const Size(900, 700), const Size(390, 560),
      const Size(360, 480)]) {
    testWidgets('purchase footer stays visible at ${size.width}x${size.height}',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.shop);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(),
          home: const Scaffold(body: V3ShopPage())),
      ));
      await tester.pumpAndSettle();
      final buy = find.widgetWithText(FilledButton, '选择套餐').first;
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      final submit = find.widgetWithText(FilledButton, '确认并创建订单');
      expect(dialog, findsOneWidget);
      expect(submit, findsOneWidget);
      expect(tester.getTopLeft(submit).dy, greaterThan(0));
      expect(tester.getBottomRight(submit).dy,
        lessThanOrEqualTo(size.height - 8));
      expect(tester.getSize(dialog).height,
        lessThanOrEqualTo(size.height - 16));
      expect(tester.takeException(), isNull);
    });
  }
}

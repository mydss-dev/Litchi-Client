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
        child: MaterialApp(
        theme: V3Theme.light(),
          home: const Scaffold(body: V3ShopPage())),
      ));
      await tester.pumpAndSettle();
      final buy = find.widgetWithText(FilledButton, '选择套餐').first;
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      final submit = find.widgetWithText(FilledButton, '确认并创建订�?);
      expect(dialog, findsOneWidget);
      expect(submit, findsOneWidget);
      final button = tester.getRect(submit);
      // Dialog itself expands to the overlay's dimensions, even though its
      // content card has viewport bounds. Verify the actionable footer itself.
      expect(button.top, greaterThan(0));
      expect(button.bottom, lessThanOrEqualTo(size.height - 8));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    });
  }
}

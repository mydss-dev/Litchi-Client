import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

void main() {
  for (final size in [const Size(900, 700), const Size(390, 560),
      const Size(360, 480)]) {
    testWidgets('checkout has a fixed preferred size with viewport safety at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.shop);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(AppScope(controller: controller,
        child: MaterialApp(theme: V3Theme.light(),
          home: const Scaffold(body: V3ShopPage()))));
      await tester.pumpAndSettle();
      final buy = find.widgetWithText(FilledButton, '选择套餐').first;
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text('高速线路')),
          findsNothing, reason: 'plan description belongs to plan details, not checkout');
      expect(find.text('选择付款周期'), findsOneWidget);
      expect(find.text('优惠码'), findsOneWidget);
      expect(find.text('实付金额'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, '确认并创建订单');
      expect(submit, findsOneWidget);
      final button = tester.getRect(submit);
      expect(button.top, greaterThan(0));
      expect(button.bottom, lessThanOrEqualTo(size.height - 8));
      final card = tester.getSize(find.byKey(kV3PurchaseDialogBodyKey));
      expect(card.width, lessThanOrEqualTo(size.width - 24));
      expect(card.height, lessThanOrEqualTo(size.height - 24));
      if (size.width == 900) {
        expect(card.width, 440);
        expect(card.height, 520);
      }
      expect(tester.takeException(), isNull);
    });
  }
}

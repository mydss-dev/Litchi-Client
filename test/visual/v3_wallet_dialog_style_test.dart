import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_wallet_actions.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_dialog_frame.dart';

import 'v3_visual_fixture.dart';

void main() {
  for (final size in [const Size(900, 700), const Size(360, 480)]) {
    testWidgets('recharge uses common frame and keeps preset choice at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.account);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(),
          home: Scaffold(body: Builder(builder: (context) => FilledButton(
            onPressed: () => showV3RechargeDialog(context),
            child: const Text('打开充值'))))),
      ));
      await tester.tap(find.text('打开充值'));
      await tester.pumpAndSettle();
      expect(find.byType(V3DialogFrame), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      final initial = find.widgetWithText(ChoiceChip, '¥100');
      expect(tester.widget<ChoiceChip>(initial).selected, isTrue);
      final fifty = find.widgetWithText(ChoiceChip, '¥50');
      await tester.ensureVisible(fifty);
      await tester.tap(fifty);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(fifty).selected, isTrue);
      expect(tester.widget<ChoiceChip>(initial).selected, isFalse);
      final submit = find.widgetWithText(FilledButton, '去支付');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      expect(tester.getRect(submit).bottom, lessThanOrEqualTo(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}

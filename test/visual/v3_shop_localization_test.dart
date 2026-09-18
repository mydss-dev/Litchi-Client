import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/pages/v3_shop_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

void main() {
  for (final (locale, heading, buyLabel, checkoutLabel) in [
    (const Locale('en'), 'Choose a plan', 'Choose plan',
        'Confirm and create order'),
    (const Locale('zh', 'TW'), '選擇方案', '選擇方案', '確認並建立訂單'),
  ]) {
    testWidgets('${locale.toLanguageTag()} shop and checkout use chosen locale',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.shop);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: V3ShopPage()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(heading), findsWidgets);
      final buy = find.widgetWithText(FilledButton, buyLabel).first;
      await tester.ensureVisible(buy);
      await tester.tap(buy);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, checkoutLabel), findsOneWidget);
      expect(find.text('优惠码'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

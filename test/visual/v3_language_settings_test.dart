import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/app_locale_preference.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/services/settings_service.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v3_visual_fixture.dart';

class _LocaleController extends VisualV3Controller {
  _LocaleController() : super(AppPage.settings);

  AppPage destination = AppPage.settings;

  @override
  AppPage get page => destination;

  @override
  void goToPage(AppPage next) {
    destination = next;
    notifyListeners();
  }
}

Future<_LocaleController> _pump(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _LocaleController();
  addTearDown(controller.disposeVisual);
  controller.setLanguage(AppLocalePreference.simplifiedChinese);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        theme: V3Theme.light(),
        locale: controller.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const V3Shell(),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _choose(WidgetTester tester, String option) async {
  final dropdown = find.byKey(const ValueKey('v3-language-select'));
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    testWidgets('settings language changes immediately and persists at $size',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final controller = await _pump(tester, size);
        expect(find.text('语言设置'), findsOneWidget);

        await _choose(tester, 'English');
        expect(controller.language, AppLocalePreference.english);
        expect(controller.locale, const Locale('en'));
        expect(find.text('Language settings'), findsOneWidget);
        // V3SectionLabel deliberately renders section titles in uppercase.
        expect(find.text('CONNECTION'), findsOneWidget);
        expect((await SettingsService.load()).language,
            AppLocalePreference.english);
        expect(tester.takeException(), isNull);

        controller.goToPage(AppPage.more);
        await tester.pumpAndSettle();
        expect(find.text('More services'), findsOneWidget);
        expect(find.text('Support'), findsOneWidget);
        expect(find.text('Client settings'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Traditional Chinese and system follow use the saved locale',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final controller = await _pump(tester, const Size(390, 844));
      await _choose(tester, '繁體中文');
      expect(controller.locale, const Locale('zh', 'TW'));
      expect(find.text('語言設定'), findsOneWidget);
      expect((await SettingsService.load()).language,
          AppLocalePreference.traditionalChinese);

      await _choose(tester, '跟隨系統');
      expect(controller.language, AppLocalePreference.system);
      expect(controller.locale, isNull);
      expect((await SettingsService.load()).language,
          AppLocalePreference.system);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

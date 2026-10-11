import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/app_locale_preference.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

/// The visual fixture pins `themeMode` to light for stable goldens, so the
/// theme assertion records the setter call instead of reading the pinned
/// getter; language has no pin and round-trips through the real settings.
class _OverlayFixture extends VisualV3Controller {
  _OverlayFixture(super.page);

  ThemeMode? requestedTheme;
  @override
  void setThemeMode(ThemeMode mode) {
    requestedTheme = mode;
    super.setThemeMode(mode);
  }
}

/// The floating title strip's quick controls must actually drive the
/// controller: the sun/moon toggle flips the theme mode, and the language
/// face opens a menu whose picks write the locale preference.
void main() {
  testWidgets('title strip quick controls drive theme and language', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await _run(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Future<void> _run(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = _OverlayFixture(AppPage.dashboard);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      theme: V3Theme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppScope(controller: controller, child: const V3Shell()),
    ),
  );
  await tester.pumpAndSettle();

  // Light mode shows the moon; tapping it commits an explicit dark mode.
  await tester.tap(find.byIcon(Icons.dark_mode_rounded));
  await tester.pump();
  expect(controller.requestedTheme, ThemeMode.dark);

  // The language face (a compact CN/TW/EN code) opens the preference menu;
  // each option is labelled in its own tongue, and picking one writes the
  // preference and flips the face to the picked code.
  await tester.tap(find.text('CN'));
  await tester.pumpAndSettle();
  expect(find.text('简体中文'), findsOneWidget);
  expect(find.text('繁體中文'), findsOneWidget);
  expect(find.text('English'), findsOneWidget);
  await tester.tap(find.text('English'));
  await tester.pumpAndSettle();
  expect(controller.language, AppLocalePreference.english);
  expect(find.text('EN'), findsOneWidget);
}

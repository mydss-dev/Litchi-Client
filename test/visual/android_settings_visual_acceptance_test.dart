import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/settings/widgets/greenfield_settings_surface.dart';
import 'package:litchi_client/l10n/app_locale_preference.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment('LITCHI_VISUAL_SNAPSHOTS');

void main() {
  Future<void> pumpSettings(WidgetTester tester, {required ThemeMode themeMode, required Size size}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: themeMode,
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(
        padding: AppShellSpec.pagePaddingFor(AppPlatform.current),
        child: GreenfieldSettingsSurface(
          secureServer: true,
          showDesktopStartup: false,
          showNetworkModeToggle: false,
          showSystemProxyTools: false,
          autoStart: false,
          silentStart: false,
          autoUpdate: true,
          themeMode: themeMode,
          language: AppLocalePreference.simplifiedChinese,
          networkMode: NetworkMode.tun,
          dnsMode: DnsMode.cloudflare,
          killSwitch: false,
          appVersion: '1.2.8',
          coreVersion: 'sing-box 1.11.4',
          coreLoaded: true,
          onAutoStartChanged: (_) {},
          onSilentStartChanged: (_) {},
          onAutoUpdateChanged: (_) {},
          onThemeModeChanged: (_) {},
          onLanguageChanged: (_) {},
          onTunChanged: (_) {},
          onDnsModeChanged: (_) {},
          onKillSwitchChanged: (_) {},
          onRepairNetwork: () {},
          onShowDiagnostics: () {},
        ),
      )),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  for (final c in const [
    _Case('light', ThemeMode.light, Size(390, 844), '390x844'),
    _Case('dark', ThemeMode.dark, Size(390, 844), '390x844'),
    _Case('light', ThemeMode.light, Size(360, 800), '360x800'),
    _Case('dark', ThemeMode.dark, Size(360, 800), '360x800'),
  ]) {
    testWidgets('Android ${c.label} settings ${c.themeName} visual', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpSettings(tester, themeMode: c.themeMode, size: c.size);
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/android_settings_${c.themeName}_${c.label}.png'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: !_visualSnapshotsEnabled);
  }
}

class _Case {
  const _Case(this.themeName, this.themeMode, this.size, this.label);
  final String themeName;
  final ThemeMode themeMode;
  final Size size;
  final String label;
}

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

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  const mainPaneSize = Size(700, 654); // 900x700 shell - 200 sidebar - 46 title bar.

  Future<void> pumpSettings(
    WidgetTester tester, {
    required ThemeMode themeMode,
  }) async {
    await tester.binding.setSurfaceSize(mainPaneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: AppShellSpec.pagePaddingFor(AppPlatform.current),
            child: GreenfieldSettingsSurface(
              secureServer: true,
              showDesktopStartup: true,
              showNetworkModeToggle: true,
              showSystemProxyTools: true,
              autoStart: true,
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
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  testWidgets(
    'Windows 900x700 settings light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpSettings(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/settings_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 settings dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpSettings(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/settings_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

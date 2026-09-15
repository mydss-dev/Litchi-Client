import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/traffic/widgets/greenfield_traffic_surface.dart';
import 'package:litchi_client/features/traffic/widgets/traffic_presentation_theme.dart';
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

  Future<void> pumpTraffic(
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
            child: TrafficPresentationTheme(
              child: GreenfieldTrafficSurface(
                traffic: const TrafficModel(
                  totalGb: 512,
                  usedGb: 128.4,
                  remainGb: 383.6,
                ),
                todayTrafficGb: 2.48,
                todayComparison: '较昨日减少 18%',
                expiryDays: 107,
                expiryDate: '2026-12-31',
                resetDay: 1,
                resetDays: 16,
                usage: _usage,
                fallbackDailyUsage: const [
                  1.8,
                  2.3,
                  3.1,
                  1.6,
                  4.2,
                  2.9,
                  2.48,
                ],
                periodDays: 7,
                onPeriodChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'Windows 900x700 traffic light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpTraffic(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/traffic_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 traffic dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpTraffic(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/traffic_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

final _usage = <TrafficUsagePoint>[
  TrafficUsagePoint(
    date: DateTime(2026, 9, 9),
    totalGb: 1.8,
    uploadGb: 0.2,
    downloadGb: 1.6,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 10),
    totalGb: 2.3,
    uploadGb: 0.3,
    downloadGb: 2.0,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 11),
    totalGb: 3.1,
    uploadGb: 0.4,
    downloadGb: 2.7,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 12),
    totalGb: 1.6,
    uploadGb: 0.2,
    downloadGb: 1.4,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 13),
    totalGb: 4.2,
    uploadGb: 0.6,
    downloadGb: 3.6,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 14),
    totalGb: 2.9,
    uploadGb: 0.4,
    downloadGb: 2.5,
  ),
  TrafficUsagePoint(
    date: DateTime(2026, 9, 15),
    totalGb: 2.48,
    uploadGb: 0.31,
    downloadGb: 2.17,
  ),
];

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/shop/widgets/greenfield_shop_surface.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  Future<void> pumpShop(
    WidgetTester tester, {
    required ThemeMode themeMode,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
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
            child: GreenfieldShopSurface(
              plans: _plans,
              selectedTab: 0,
              currencySymbol: '¥',
              hasActivePlan: true,
              currentPlanName: 'Litchi Ultra · 512G',
              remainingTraffic: '383.6 GB',
              expiryLabel: '2026-12-31',
              onSelectedTab: (_) {},
              onPurchase: (_, _) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  for (final caseData in const [
    _Case('light', ThemeMode.light, Size(390, 844), '390x844'),
    _Case('dark', ThemeMode.dark, Size(390, 844), '390x844'),
    _Case('light', ThemeMode.light, Size(360, 800), '360x800'),
    _Case('dark', ThemeMode.dark, Size(360, 800), '360x800'),
  ]) {
    testWidgets(
      'Android ${caseData.label} shop ${caseData.themeName} visual',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await pumpShop(
            tester,
            themeMode: caseData.themeMode,
            size: caseData.size,
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/android_shop_${caseData.themeName}_${caseData.label}.png',
            ),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
      skip: !_visualSnapshotsEnabled,
    );
  }
}

class _Case {
  const _Case(this.themeName, this.themeMode, this.size, this.label);

  final String themeName;
  final ThemeMode themeMode;
  final Size size;
  final String label;
}

const _plans = <PlanModel>[
  PlanModel(
    id: 'ultra',
    title: 'Litchi Ultra',
    capacity: '512G',
    category: PlanCategory.recurring,
    monthlyPrice: 12.8,
    quarterlyPrice: 35.0,
    yearlyPrice: 118.0,
    deviceLimit: 5,
    features: ['高速中转线路', '全球节点', '流媒体解锁'],
    featured: true,
  ),
  PlanModel(
    id: 'prime',
    title: 'Litchi Prime',
    capacity: '1024G',
    category: PlanCategory.recurring,
    monthlyPrice: 22.8,
    quarterlyPrice: 62.0,
    yearlyPrice: 208.0,
    deviceLimit: 8,
    features: ['更高流量额度', '优先线路', '多设备支持'],
    hot: true,
  ),
  PlanModel(
    id: 'one-time',
    title: 'Litchi Flex',
    capacity: '288G',
    category: PlanCategory.oneTime,
    oneTimePrice: 58.0,
    deviceLimit: 3,
    features: ['一次购买', '不限月付周期', '适合轻量使用'],
  ),
  PlanModel(
    id: 'data-pack',
    title: '流量补充包',
    capacity: '188G',
    category: PlanCategory.dataPack,
    oneTimePrice: 28.0,
    features: ['叠加当前套餐', '即时生效'],
  ),
];

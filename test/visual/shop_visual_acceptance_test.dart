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
  const mainPaneSize = Size(700, 654); // 900x700 shell - 200 sidebar - 46 title bar.

  Future<void> pumpShop(
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

  testWidgets(
    'Windows 900x700 shop light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpShop(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/shop_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 shop dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpShop(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/shop_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
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

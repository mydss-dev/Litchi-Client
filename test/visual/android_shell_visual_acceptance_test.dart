import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/app_window_bar.dart';
import 'package:litchi_client/app/nav_destinations.dart';
import 'package:litchi_client/l10n/app_locale_preference.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_layout.dart';
import 'package:litchi_client/shared/theme/app_colors.dart';
import 'package:litchi_client/shared/theme/app_radius.dart';
import 'package:litchi_client/shared/theme/app_shadows.dart';
import 'package:litchi_client/shared/theme/app_spacing.dart';
import 'package:litchi_client/shared/theme/app_text_styles.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';
import 'package:litchi_client/shared/widgets/app_card.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    required ThemeMode themeMode,
    required AppPage page,
    required bool profileChild,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _ShellVisualController(
      page: page,
      profileChild: profileChild,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 24, bottom: 20),
          ),
          child: AppScope(
            controller: controller,
            child: Scaffold(
              body: _VisualCompactShell(
                page: page,
                profileChild: profileChild,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  for (final size in const [Size(390, 844), Size(360, 800)]) {
    final suffix = '${size.width.toInt()}x${size.height.toInt()}';
    for (final themeMode in const [ThemeMode.light, ThemeMode.dark]) {
      final theme = themeMode == ThemeMode.light ? 'light' : 'dark';

      testWidgets(
        'Android compact shell dashboard $theme $suffix',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            await pumpShell(
              tester,
              size: size,
              themeMode: themeMode,
              page: AppPage.dashboard,
              profileChild: false,
            );
            await expectLater(
              find.byType(Scaffold),
              matchesGoldenFile(
                'goldens/android_shell_dashboard_${theme}_$suffix.png',
              ),
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        },
        skip: !_visualSnapshotsEnabled,
      );

      testWidgets(
        'Android compact shell settings child $theme $suffix',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          try {
            await pumpShell(
              tester,
              size: size,
              themeMode: themeMode,
              page: AppPage.settings,
              profileChild: true,
            );
            await expectLater(
              find.byType(Scaffold),
              matchesGoldenFile(
                'goldens/android_shell_settings_${theme}_$suffix.png',
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
}

class _ShellVisualController extends AppController {
  _ShellVisualController({required this.page, required this.profileChild});

  @override
  final AppPage page;

  final bool profileChild;

  @override
  bool get mobileProfileChildPage => profileChild;

  @override
  AppLocalePreference get language => AppLocalePreference.simplifiedChinese;
}

class _VisualCompactShell extends StatelessWidget {
  const _VisualCompactShell({
    required this.page,
    required this.profileChild,
  });

  final AppPage page;
  final bool profileChild;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      color: c.appBg,
      child: Column(
        children: [
          const SafeArea(bottom: false, child: MobileTitleBar()),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  const Expanded(
                    child: Padding(
                      padding: AppLayoutMetrics.compactPagePadding,
                      child: _RepresentativeBody(),
                    ),
                  ),
                  _VisualMobileBottomNav(
                    bottomPadding: bottom,
                    currentPage: page,
                    profileChild: profileChild,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepresentativeBody extends StatelessWidget {
  const _RepresentativeBody();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Litchi',
                  style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Compact shell acceptance',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            shadow: AppCardShadow.none,
            child: SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(child: Container(color: c.surfaceMuted)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Container(color: c.surfaceMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the production compact navigation presentation while reusing the
/// production destination metadata and selected-primary mapping. The production
/// widget is private to AppShell; this visual harness intentionally keeps the
/// copy test-only so no shell behavior is changed for acceptance rendering.
class _VisualMobileBottomNav extends StatelessWidget {
  const _VisualMobileBottomNav({
    required this.bottomPadding,
    required this.currentPage,
    required this.profileChild,
  });

  final double bottomPadding;
  final AppPage currentPage;
  final bool profileChild;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final compactPadding = AppLayoutMetrics.compactPagePadding;
    final selectedPrimary = compactSelectedPrimary(currentPage, profileChild);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compactPadding.left,
        4,
        compactPadding.right,
        bottomPadding + compactPadding.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Row(
          children: [
            for (final item in compactPrimaryDestinations)
              Expanded(
                child: _VisualMobileNavButton(
                  item: item,
                  selected: selectedPrimary == item.page,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VisualMobileNavButton extends StatelessWidget {
  const _VisualMobileNavButton({required this.item, required this.selected});

  final NavDestination item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.primary : c.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: AppLayoutMetrics.minTouchTarget,
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 18, color: color),
              const SizedBox(height: 3),
              Text(
                item.labelFor(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

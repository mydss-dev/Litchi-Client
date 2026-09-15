import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/account/widgets/greenfield_account_surface.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  Future<void> pumpAccount(
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
            child: GreenfieldAccountSurface(
              userName: 'Bruce',
              avatarLetter: 'B',
              hasPlan: true,
              planName: 'Litchi Ultra · 512G',
              expiryLabel: '2026-12-31',
              balanceText: '¥128.80',
              commissionText: '¥58.20',
              showOrders: true,
              showTraffic: true,
              showInvite: true,
              showGiftCard: true,
              showTelegram: true,
              telegramBound: true,
              remindExpire: true,
              remindTraffic: true,
              autoRenewal: false,
              onPlanAction: () {},
              onWallet: () {},
              onRecharge: () {},
              onTransfer: () {},
              onWithdraw: () {},
              onOrders: () {},
              onTraffic: () {},
              onInvite: () {},
              onGiftCard: () {},
              onTelegram: () {},
              onExpireChanged: (_) {},
              onTrafficChanged: (_) {},
              onAutoRenewalChanged: (_) {},
              onChangePassword: () {},
              onLogout: () {},
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
      'Android ${caseData.label} account ${caseData.themeName} visual',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await pumpAccount(
            tester,
            themeMode: caseData.themeMode,
            size: caseData.size,
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/android_account_${caseData.themeName}_${caseData.label}.png',
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

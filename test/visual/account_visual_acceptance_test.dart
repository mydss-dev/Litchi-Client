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
  const mainPaneSize = Size(700, 654); // 900x700 shell - 200 sidebar - 46 title bar.

  Future<void> pumpAccount(
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

  testWidgets(
    'Windows 900x700 account light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpAccount(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/account_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 account dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpAccount(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/account_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

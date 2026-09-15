import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/invite/widgets/greenfield_invite_surface.dart';
import 'package:litchi_client/features/invite/widgets/invite_presentation_theme.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  const mainPaneSize = Size(700, 654); // 900x700 shell - 200 sidebar - 46 title bar.

  Future<void> pumpInvite(
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
            child: InvitePresentationTheme(
              child: GreenfieldInviteSurface(
                invite: const InviteCodeModel(
                  code: 'LITCHI88',
                  link: 'https://thelitchi.com/register?aff=LITCHI88',
                ),
                selectedIndex: 0,
                inviteCount: 3,
                creating: false,
                registeredUsers: 27,
                pendingCommission: r'$18.42',
                earnedCommission: r'$126.80',
                commissionRate: '20%',
                records: _records,
                currencySymbol: r'$',
                onPrevious: () {},
                onNext: () {},
                onCreate: () {},
                onCopy: () {},
                onShareWechat: () {},
                onShareQq: () {},
                onShareTwitter: () {},
                onShareTelegram: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  testWidgets(
    'Windows 900x700 invite light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpInvite(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/invite_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 invite dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpInvite(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/invite_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

const _records = <RemoteInviteRecord>[
  RemoteInviteRecord(
    id: 1,
    tradeNo: 'INV-20260915-001',
    userName: 'al***@example.com',
    orderAmount: 1280,
    commissionAmount: 256,
    createdAt: 1789430400,
  ),
  RemoteInviteRecord(
    id: 2,
    tradeNo: 'INV-20260914-021',
    userName: 'br***@example.com',
    orderAmount: 5800,
    commissionAmount: 1160,
    createdAt: 1789344000,
  ),
  RemoteInviteRecord(
    id: 3,
    tradeNo: 'INV-20260912-008',
    userName: 'ch***@example.com',
    orderAmount: 2800,
    commissionAmount: 560,
    createdAt: 1789171200,
  ),
];

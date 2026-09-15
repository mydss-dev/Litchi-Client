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
  Future<void> pumpInvite(
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

  for (final caseData in const [
    _Case('light', ThemeMode.light, Size(390, 844), '390x844'),
    _Case('dark', ThemeMode.dark, Size(390, 844), '390x844'),
    _Case('light', ThemeMode.light, Size(360, 800), '360x800'),
    _Case('dark', ThemeMode.dark, Size(360, 800), '360x800'),
  ]) {
    testWidgets(
      'Android ${caseData.label} invite ${caseData.themeName} visual',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await pumpInvite(
            tester,
            themeMode: caseData.themeMode,
            size: caseData.size,
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/android_invite_${caseData.themeName}_${caseData.label}.png',
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

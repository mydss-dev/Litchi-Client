import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/tickets/widgets/greenfield_tickets_surface.dart';
import 'package:litchi_client/features/tickets/widgets/tickets_presentation_theme.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment('LITCHI_VISUAL_SNAPSHOTS');

void main() {
  Future<void> pumpTickets(WidgetTester tester, {required ThemeMode themeMode, required Size size}) async {
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
        child: TicketsPresentationTheme(child: GreenfieldTicketsSurface(
          tickets: _tickets,
          onOpenTicket: (_) {},
          onCreateTicket: () {},
        )),
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
    testWidgets('Android ${c.label} tickets ${c.themeName} visual', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpTickets(tester, themeMode: c.themeMode, size: c.size);
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/android_tickets_${c.themeName}_${c.label}.png'));
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

const _tickets = <TicketModel>[
  TicketModel(id: 1042, subject: '香港节点连接后偶发无法访问部分网站', level: 2, status: 0, createdAt: 1789430400, updatedAt: 1789437600),
  TicketModel(id: 1038, subject: '套餐流量重置时间咨询', level: 1, status: 0, createdAt: 1789344000, updatedAt: 1789351200),
  TicketModel(id: 1027, subject: 'Windows 客户端升级后需要重新登录吗', level: 1, status: 1, createdAt: 1789171200, updatedAt: 1789257600),
  TicketModel(id: 1019, subject: '邀请返佣到账记录确认', level: 0, status: 1, createdAt: 1788825600, updatedAt: 1788912000),
];

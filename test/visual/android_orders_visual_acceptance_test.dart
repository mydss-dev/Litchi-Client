import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/orders/widgets/greenfield_orders_surface.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment('LITCHI_VISUAL_SNAPSHOTS');

void main() {
  Future<void> pumpOrders(WidgetTester tester, {required ThemeMode themeMode, required Size size}) async {
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
        child: GreenfieldOrdersSurface(
          orders: _orders,
          currencySymbol: r'$',
          activeTradeNo: null,
          onPay: (_) {},
          onCancel: (_) {},
        ),
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
    testWidgets('Android ${c.label} orders ${c.themeName} visual', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpOrders(tester, themeMode: c.themeMode, size: c.size);
        await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/android_orders_${c.themeName}_${c.label}.png'));
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

const _orders = <RemoteOrder>[
  RemoteOrder(tradeNo: '2026091500012841', planName: 'Litchi Ultra · 512G', period: 'month_price', totalAmount: 1280, status: 0, createdAt: 1789430400),
  RemoteOrder(tradeNo: '2026091400009820', planName: 'Litchi Prime · 1024G', period: 'year_price', totalAmount: 8800, status: 1, createdAt: 1789344000),
  RemoteOrder(tradeNo: '2026091200004416', planName: 'Litchi Ultra · 512G', period: 'quarter_price', totalAmount: 3200, status: 3, createdAt: 1789171200),
  RemoteOrder(tradeNo: '2026090800001732', planName: 'Litchi Data Pack · 188G', period: 'onetime_price', totalAmount: 5800, status: 4, createdAt: 1788825600),
];

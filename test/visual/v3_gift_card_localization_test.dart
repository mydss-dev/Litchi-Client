import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/l10n/generated/app_localizations_en.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/pages/v3_gift_card_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _RecordingRedeemApi extends PanelApi {
  _RecordingRedeemApi() : super(ApiClient());

  int calls = 0;
  String? lastCode;
  Object? error;

  @override
  Future<void> redeemGiftCard(String code) async {
    calls++;
    lastCode = code;
    if (error != null) throw error!;
  }
}

class _GiftFixture extends VisualV3Controller {
  _GiftFixture() : super(AppPage.giftCard);

  final redeemApi = _RecordingRedeemApi();
  int refreshes = 0;
  bool failRefresh = false;

  @override
  PanelApi get api => redeemApi;

  @override
  Future<void> refreshData() async {
    refreshes++;
    if (failRefresh) throw StateError('refresh offline');
  }
}

Future<void> _pumpGift(
  WidgetTester tester,
  _GiftFixture fixture, {
  Locale locale = const Locale('en'),
  Size size = const Size(900, 700),
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(fixture.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: fixture,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: V3Theme.light(),
        darkTheme: V3Theme.dark(),
        themeMode: mode,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: V3GiftCardPage(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('English form explains backend-defined benefits and validates code', (
    tester,
  ) async {
    final fixture = _GiftFixture();
    await _pumpGift(tester, fixture);
    expect(find.textContaining('may include balance, traffic, duration'), findsOneWidget);
    expect(find.textContaining('金额会直接充入'), findsNothing);
    await tester.tap(find.text('Redeem now'));
    await tester.pump();
    expect(find.text(AppLocalizationsEn().giftCardEnterRequired), findsOneWidget);
    expect(fixture.redeemApi.calls, 0);
  });

  testWidgets('successful redemption is not reported as failure if refresh fails', (
    tester,
  ) async {
    final fixture = _GiftFixture()..failRefresh = true;
    await _pumpGift(tester, fixture);
    await tester.enterText(find.byType(TextField), '  GIFT-ONE  ');
    await tester.tap(find.text('Redeem now'));
    await tester.pumpAndSettle();
    expect(fixture.redeemApi.calls, 1);
    expect(fixture.redeemApi.lastCode, 'GIFT-ONE');
    expect(fixture.refreshes, 1);
    expect(find.textContaining('Redeemed successfully, but account refresh failed'), findsOneWidget);
    expect(find.textContaining('do not redeem the same code again'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('backend error does not clear the code or claim success', (
    tester,
  ) async {
    final fixture = _GiftFixture()
      ..redeemApi.error = StateError('当前面板不支持此功能');
    await _pumpGift(tester, fixture);
    await tester.enterText(find.byType(TextField), 'GIFT-ONE');
    await tester.tap(find.text('Redeem now'));
    await tester.pumpAndSettle();
    expect(fixture.redeemApi.calls, 1);
    expect(fixture.refreshes, 0);
    expect(find.text(AppLocalizationsEn().unexpectedError), findsOneWidget);
    expect(find.textContaining('Redeemed successfully'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'GIFT-ONE');
  });

  for (final (locale, expected) in <(Locale, String)>[
    (const Locale('zh'), '实际权益以兑换码为准'),
    (const Locale('zh', 'TW'), '實際權益依兌換碼而定'),
  ]) {
    testWidgets('$locale uses localized and accurate benefit copy', (tester) async {
      final fixture = _GiftFixture();
      await _pumpGift(tester, fixture, locale: locale);
      expect(find.textContaining(expected), findsOneWidget);
      expect(find.textContaining('金额会直接充入账户余额'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('compact redemption form has no overflow in $mode', (tester) async {
      final fixture = _GiftFixture();
      await _pumpGift(tester, fixture, size: const Size(360, 800), mode: mode);
      expect(tester.takeException(), isNull);
      expect(find.text('Redeem now'), findsOneWidget);
    });
  }
}

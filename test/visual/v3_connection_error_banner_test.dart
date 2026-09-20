import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/app/core_error_message_service.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_dashboard_alerts.dart';

import 'v3_visual_fixture.dart';

class _AlertFixture extends VisualV3Controller {
  _AlertFixture() : super(AppPage.dashboard);

  ConnectionStatus state = ConnectionStatus.error;
  String failure = CoreErrorMessageService.proxyPortUnavailable;
  String? warning;
  bool retrySucceeds = true;
  int connectionRetries = 0;
  int dataRetries = 0;

  @override
  ConnectionStatus get connectionStatus => state;

  @override
  String get coreError => failure;

  @override
  String? get dataLoadError => warning;

  @override
  Future<String?> toggleConnection() async {
    connectionRetries++;
    if (retrySucceeds) {
      state = ConnectionStatus.connected;
      failure = '';
      notifyListeners();
      return null;
    }
    state = ConnectionStatus.error;
    notifyListeners();
    return failure;
  }

  @override
  Future<void> refreshData() async {
    dataRetries++;
    warning = null;
    notifyListeners();
  }
}

Future<void> _pump(
  WidgetTester tester,
  _AlertFixture controller, {
  required Size size,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        darkTheme: V3Theme.dark(),
        themeMode: themeMode,
        home: const Scaffold(body: V3DashboardPage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final (size, mode) in [
    (const Size(900, 700), ThemeMode.light),
    (const Size(900, 700), ThemeMode.dark),
    (const Size(360, 800), ThemeMode.light),
    (const Size(360, 800), ThemeMode.dark),
  ]) {
    testWidgets('connection warning fits $size in $mode', (tester) async {
      final controller = _AlertFixture();
      await _pump(tester, controller, size: size, themeMode: mode);

      final alert = find.byKey(kV3ConnectionErrorBannerKey);
      expect(alert, findsOneWidget);
      expect(find.text(CoreErrorMessageService.proxyPortUnavailable), findsOneWidget);
      expect(find.descendant(of: alert, matching: find.text('重试')), findsOneWidget);
      expect(find.descendant(of: alert,
          matching: find.byIcon(Icons.error_outline_rounded)), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed retry stays actionable until a connection succeeds',
      (tester) async {
    final controller = _AlertFixture()..retrySucceeds = false;
    await _pump(tester, controller, size: const Size(900, 700));

    await tester.tap(find.descendant(
      of: find.byKey(kV3ConnectionErrorBannerKey),
      matching: find.text('重试'),
    ));
    await tester.pump();
    expect(controller.connectionRetries, 1);
    expect(find.byKey(kV3ConnectionErrorBannerKey), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    controller.retrySucceeds = true;
    await tester.tap(find.descendant(
      of: find.byKey(kV3ConnectionErrorBannerKey),
      matching: find.text('重试'),
    ));
    await tester.pump();
    expect(controller.connectionRetries, 2);
    expect(find.byKey(kV3ConnectionErrorBannerKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('core logs are replaced with a user-facing error', (tester) async {
    final controller = _AlertFixture()
      ..failure = 'time=2026-09-20 level=error msg=core failed '\n          'internal service details that should not be displayed verbatim';
    await _pump(tester, controller, size: const Size(900, 700));

    expect(find.byKey(kV3ConnectionErrorBannerKey), findsOneWidget);
    expect(find.text(controller.failure), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('data outage remains a separate yellow alert with its own retry',
      (tester) async {
    final controller = _AlertFixture()
      ..warning = '服务器连接失败，已启用本地缓存模式';
    await _pump(
      tester,
      controller,
      size: const Size(360, 800),
      themeMode: ThemeMode.dark,
    );

    final connection = find.byKey(kV3ConnectionErrorBannerKey);
    final data = find.byKey(kV3DataWarningBannerKey);
    expect(connection, findsOneWidget);
    expect(data, findsOneWidget);
    expect(find.descendant(of: data,
        matching: find.byIcon(Icons.warning_amber_rounded)), findsOneWidget);
    final warningText = tester.widget<Text>(find.descendant(
      of: data,
      matching: find.byType(Text),
    ).first);
    expect(warningText.style?.color, V3Palette.dark.warningInk);
    expect(tester.takeException(), isNull);

    await tester.tap(find.descendant(of: data, matching: find.text('重试')));
    await tester.pump();
    expect(controller.dataRetries, 1);
    expect(find.byKey(kV3DataWarningBannerKey), findsNothing);
    expect(find.byKey(kV3ConnectionErrorBannerKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _SystemModeController extends VisualV3Controller {
  _SystemModeController() : super(AppPage.dashboard);

  @override
  NetworkMode get networkMode => NetworkMode.system;
}

void main() {
  for (final (mode, palette) in [
    (ThemeMode.light, V3Palette.light),
    (ThemeMode.dark, V3Palette.dark),
  ]) {
    testWidgets('$mode configured network mode matches pink plan-cycle selection',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _SystemModeController();
      addTearDown(controller.disposeVisual);

      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(), darkTheme: V3Theme.dark(), themeMode: mode,
          home: const Scaffold(body: V3DashboardPage()),
        ),
      ));
      await tester.pump();

      final selected = tester.widget<Container>(
        find.byKey(const ValueKey('v3-network-mode-system')));
      final other = tester.widget<Container>(
        find.byKey(const ValueKey('v3-network-mode-tun')));
      final selectedDecoration = selected.decoration! as BoxDecoration;
      final otherDecoration = other.decoration! as BoxDecoration;
      expect(selectedDecoration.color, palette.lycheeSoft);
      expect(selectedDecoration.border!.top.color, palette.lychee);
      expect(otherDecoration.color, palette.surfaceRaised);
      expect(otherDecoration.border!.top.color, palette.line);
      expect(tester.widget<Text>(find.text('系统代理')).style!.color,
        palette.lycheeInk);
      expect(tester.widget<Text>(find.text('TUN 模式')).style!.color,
        palette.inkMuted);
      expect(tester.takeException(), isNull);
    });
  }
}

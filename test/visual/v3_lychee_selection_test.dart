import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

class _SystemModeController extends VisualV3Controller {
  _SystemModeController() : super(AppPage.dashboard);

  @override
  NetworkMode get networkMode => NetworkMode.system;
}

class _AutoSelectedController extends VisualV3Controller {
  _AutoSelectedController() : super(AppPage.dashboard);

  @override
  bool get autoSelected => true;
}

void main() {
  for (final (mode, palette) in [
    (ThemeMode.light, V3Palette.light),
    (ThemeMode.dark, V3Palette.dark),
  ]) {
    testWidgets('$mode configured network mode matches pink plan-cycle selection',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
      expect((selectedDecoration.border! as Border).top.color, palette.lychee);
      expect(otherDecoration.color, palette.surfaceRaised);
      expect((otherDecoration.border! as Border).top.color, palette.line);
      expect(tester.widget<Text>(find.text('系统代理')).style!.color,
        palette.lycheeInk);
      expect(tester.widget<Text>(find.text('TUN 模式')).style!.color,
        palette.inkMuted);
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode automatic node selection has no green selected icon',
        (tester) async {
      final controller = _AutoSelectedController();
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(), darkTheme: V3Theme.dark(), themeMode: mode,
        home: Scaffold(body: V3AutoRouteRow(
          controller: controller, busy: false, onTap: null)),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome_rounded));
      expect(icon.color, palette.lycheeInk);
      expect(icon.color, isNot(palette.successInk));
      expect(tester.takeException(), isNull);
    });
  }
}

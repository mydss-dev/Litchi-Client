import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_settings_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _InteractiveController extends VisualV3Controller {
  _InteractiveController(super.page);
  AppPage? destination;
  int selections = 0;
  int networkChanges = 0;
  Completer<String?> result = Completer<String?>();

  @override
  void goToPage(AppPage page) => destination = page;

  @override
  Future<String?> setCurrentNode(NodeModel node) {
    selections++;
    return result.future;
  }

  @override
  Future<String?> setNetworkMode(NetworkMode mode) {
    networkChanges++;
    return result.future;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _InteractiveController controller,
  Widget page, {
  Size size = const Size(900, 700),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.dark(),
      home: Scaffold(
        body: AppScope(controller: controller, child: page),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Dashboard opens node selection', (tester) async {
    final controller = _InteractiveController(AppPage.dashboard);
    await _pump(tester, controller, const V3DashboardPage());
    await tester.tap(find.text('切换节点'));
    expect(controller.destination, AppPage.nodes);
  });

  testWidgets('Node change prevents duplicate requests and reports failure', (
    tester,
  ) async {
    final controller = _InteractiveController(AppPage.nodes);
    await _pump(tester, controller, const V3NodesPage());
    await tester.tap(find.text('香港 · Premium'));
    await tester.pump();
    expect(find.text('正在处理，请稍候…'), findsOneWidget);
    await tester.tap(find.text('新加坡 · Standard'));
    expect(controller.selections, 1);
    controller.result.complete('节点切换失败');
    await tester.pump();
    expect(find.text('节点切换失败'), findsOneWidget);
    controller.result = Completer<String?>();
    await tester.tap(find.text('香港 · Premium'));
    expect(controller.selections, 2);
    controller.result.complete(null);
    await tester.pump();
    expect(find.textContaining('已选择 香港'), findsOneWidget);
  });

  testWidgets('Network settings await result and display errors', (
    tester,
  ) async {
    final controller = _InteractiveController(AppPage.settings);
    await _pump(tester, controller, const V3SettingsPage());
    await tester.tap(find.text('系统代理'));
    await tester.pump();
    expect(find.text('正在应用设置，请稍候…'), findsOneWidget);
    controller.result.complete('核心未响应');
    await tester.pump();
    expect(find.textContaining('核心未响应'), findsOneWidget);
    expect(controller.networkChanges, 1);
  });

  for (final page in [
    AppPage.traffic,
    AppPage.invite,
    AppPage.settings,
    AppPage.orders,
  ]) {
    testWidgets('Compact navigation places $page under account', (
      tester,
    ) async {
      final controller = _InteractiveController(page);
      await _pump(
        tester,
        controller,
        const V3Shell(),
        size: const Size(390, 844),
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

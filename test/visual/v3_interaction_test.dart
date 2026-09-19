import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/pages/v3_settings_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

class _InteractiveController extends VisualV3Controller {
  _InteractiveController(super.page);
  AppPage? destination;
  int selections = 0;
  int networkChanges = 0;
  Completer<String?> result = Completer<String?>();

  /// Stands in for a connection change being in flight.
  bool locked = false;

  @override
  bool get connectionActionLocked => locked;

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
  // AppScope above MaterialApp, as in `LitchiApp`. A dialog is built by the
  // Navigator, so it sits beside `home` rather than under it and cannot see a
  // scope that `home` introduces.
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.dark(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // The connect orb is the page's primary action and carries no text of its
  // own, so its label is the only thing a screen reader has to go on.
  testWidgets('the connect orb announces the action it will perform', (
    tester,
  ) async {
    // Released inside the body rather than in a tear-down: the framework checks
    // for leaked handles at the end of the body, before tear-downs run.
    final semantics = tester.ensureSemantics();
    try {
      // The fixture reports a live connection, so the orb's action is to end it.
      final controller = _InteractiveController(AppPage.dashboard);
      await _pump(tester, controller, const V3DashboardPage());

      expect(
        tester.getSemantics(find.byKey(kConnectOrbKey)),
        isSemantics(label: '断开连接', isButton: true, isEnabled: true),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('the connect orb reports when it cannot be pressed', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final controller = _InteractiveController(AppPage.dashboard)
        ..locked = true;
      await _pump(tester, controller, const V3DashboardPage());

      expect(
        tester.getSemantics(find.byKey(kConnectOrbKey)),
        isSemantics(label: '断开连接', isButton: true, isEnabled: false),
      );
    } finally {
      semantics.dispose();
    }
  });

  // Switching a node happens while looking at the connection it affects, so
  // the dashboard opens the picker over itself instead of sending the user to
  // the nodes page and back.
  testWidgets('Dashboard opens the node picker over the page', (tester) async {
    final controller = _InteractiveController(AppPage.dashboard);
    await _pump(tester, controller, const V3DashboardPage());
    await tester.tap(find.text('切换节点'));
    await tester.pumpAndSettle();

    expect(find.byType(V3NodePicker), findsOneWidget);
    expect(
      controller.destination,
      isNull,
      reason: '切换节点 must open a picker, not navigate',
    );

    await tester.tap(find.text('香港 · Premium'));
    await tester.pump();
    controller.result.complete(null);
    await tester.pumpAndSettle();

    expect(controller.selections, 1);
    expect(
      find.byType(V3NodePicker),
      findsNothing,
      reason: 'a chosen node closes the picker',
    );
    expect(tester.takeException(), isNull);
  });

  // The picker stays up on failure: the request was refused, so there is
  // nothing to go back to and the list is where the retry happens.
  testWidgets('A refused node switch leaves the picker open', (tester) async {
    final controller = _InteractiveController(AppPage.dashboard);
    await _pump(tester, controller, const V3DashboardPage());
    await tester.tap(find.text('切换节点'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('香港 · Premium'));
    await tester.pump();
    controller.result.complete('节点切换失败');
    await tester.pumpAndSettle();

    expect(find.byType(V3NodePicker), findsOneWidget);
    expect(find.text('节点切换失败'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nodes overview has no selection or speed test; picker remains on dashboard',
      (tester) async {
    final controller = _InteractiveController(AppPage.nodes);
    await _pump(tester, controller, const V3NodesPage());
    await tester.ensureVisible(find.text('香港 · Premium'));
    await tester.pump();
    expect(find.text('全部测速'), findsNothing);
    expect(find.text('选择节点'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.ancestor(of: find.text('香港 · Premium'),
      matching: find.byType(InkWell)), findsNothing);
    expect(controller.selections, 0);
    expect(tester.takeException(), isNull);
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

  // Compact IA: account business sits under 账户, everything else under 更多.
  // Expected indexes are read off the nav model rather than hardcoded, so a tab
  // added or removed later cannot leave a stale number behind.
  for (final (page, tab) in [
    (AppPage.orders, AppPage.account),
    (AppPage.traffic, AppPage.more),
    (AppPage.invite, AppPage.more),
    (AppPage.settings, AppPage.more),
  ]) {
    testWidgets('Compact navigation places $page under ${tab.name}', (
      tester,
    ) async {
      final controller = _InteractiveController(page);
      await _pump(
        tester,
        controller,
        const V3Shell(),
        size: const Size(390, 844),
      );
      final expected = enabledNavItems(
        kMobilePrimary,
      ).indexWhere((item) => item.page == tab);
      expect(expected, isNonNegative, reason: '${tab.name} must be a tab');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        expected,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

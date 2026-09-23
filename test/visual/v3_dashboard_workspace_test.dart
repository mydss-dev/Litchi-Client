import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/connectivity_check_service.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _SystemProxyFixture extends VisualV3Controller {
  _SystemProxyFixture() : super(AppPage.dashboard);

  @override
  NetworkMode get networkMode => NetworkMode.system;
}

class _AutoNamedFixture extends VisualV3Controller {
  _AutoNamedFixture() : super(AppPage.dashboard);

  @override
  bool get autoSelected => true;

  @override
  NodeModel get currentNode => const NodeModel(
    id: 'hk-01',
    name: '香港 · Premium',
    flag: '🇭🇰',
    code: 'HK',
    englishName: 'Hong Kong',
    latency: 31,
    region: NodeRegion.asia,
    tags: ['IPLC', '高级'],
  );
}

class _DisconnectedFixture extends VisualV3Controller {
  _DisconnectedFixture() : super(AppPage.dashboard);

  @override
  ConnectionStatus get connectionStatus => ConnectionStatus.disconnected;
}

void main() {
  for (final size in [const Size(900, 700), const Size(390, 700)]) {
    testWidgets('dashboard cards stay balanced at ${size.width}x${size.height}',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.dashboard);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(),
          home: const Scaffold(body: V3DashboardPage())),
      ));
      await tester.pump();

      final connect = find.byKey(kConnectActionCardKey);
      final node = find.byKey(kCurrentNodeCardKey);
      expect(connect, findsOneWidget);
      expect(node, findsOneWidget);
      expect(find.byKey(const ValueKey('v3-network-mode-system')), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-network-mode-tun')), findsOneWidget);
      expect(find.text('系统代理'), findsOneWidget);
      expect(find.text('TUN 模式'), findsOneWidget);
      expect(find.text('切换节点'), findsOneWidget);
      expect(find.text('规则'), findsOneWidget);
      expect(find.text('全局'), findsOneWidget);
      expect(find.text('直连'), findsOneWidget);

      final left = tester.getRect(connect);
      final right = tester.getRect(node);
      if (size.width >= 900) {
        expect((left.top - right.top).abs(), lessThan(1));
        expect((left.height - right.height).abs(), lessThan(1));
        expect((left.width - right.width).abs(), lessThan(1));
      } else {
        expect(left.bottom, lessThan(right.top));
      }
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('configured system proxy is highlighted instead of TUN',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _SystemProxyFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    final active = tester.widget<Text>(find.text('系统代理'));
    final inactive = tester.widget<Text>(find.text('TUN 模式'));
    // The segmented capsule marks the selection with ink color, not weight.
    expect(active.style?.color, V3Palette.light.lycheeInk);
    expect(inactive.style?.color, V3Palette.light.inkMuted);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('auto selection names the resolved node and shows its tags',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _AutoNamedFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    // The resolved node name replaces the generic 自动选择 label.
    expect(find.text('香港 · Premium'), findsOneWidget);
    // The auto pill marks the mode next to the resolved name.
    expect(find.text('自动'), findsOneWidget);
    // The resolved node's tags are visible in automatic mode too.
    expect(find.text('IPLC'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan card shows an evidence-based expiry countdown',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = VisualV3Controller(AppPage.dashboard);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    // The fixture carries subscription expiry evidence, so the plan card
    // pairs the date with a days-remaining countdown.
    expect(find.textContaining(RegExp(r'剩余 \d+ 天')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('connectivity strip probes and renders results when connected',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ConnectivityCheckService.override = (target) async {
      if (target.name == 'Google') {
        return const ConnectivityResult(ok: true, latencyMs: 12);
      }
      if (target.name == '百度') {
        return const ConnectivityResult(ok: false, latencyMs: -1);
      }
      return const ConnectivityResult(ok: true, latencyMs: 40);
    };
    addTearDown(() => ConnectivityCheckService.override = null);
    final controller = VisualV3Controller(AppPage.dashboard);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    await tester.tap(find.text('重新检测'));
    await tester.pump();
    await tester.pump();

    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('40 ms'), findsNWidgets(2));
    expect(find.text('不通'), findsOneWidget);
    // The run finished: the spinner gave the button its label back.
    expect(find.text('重新检测'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('connectivity strip shows the idle hint when disconnected',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _DisconnectedFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    expect(find.text('连接后可检测各站点连通性'), findsOneWidget);
    expect(find.text('检测中'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}

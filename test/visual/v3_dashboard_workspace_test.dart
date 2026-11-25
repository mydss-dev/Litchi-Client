import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
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

void main() {
  // §13.3/§13.4 端分治: android left the merged card for the plan-A minimal
  // connection section (asserted in its own test below), while the desktop
  // keeps the three-surface workspace untouched - these geometry assertions
  // hold for the desktop branch only.
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
        // New desktop composition (blueprint §2.2): the dot-map stage owns
        // the left pane and the glass control panel floats to its right,
        // carrying the node section inside it.
        expect(left.right, lessThanOrEqualTo(right.left),
            reason: 'the map stage sits left of the control panel');
        expect(left.width, greaterThan(right.width),
            reason: 'the stage is wider than the 320dp panel section');
        expect(left.height, greaterThanOrEqualTo(right.height));
      } else {
        // Narrow windows stack the stage above the panel.
        expect(left.bottom, lessThanOrEqualTo(right.top));
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

  testWidgets('android renders the plan-A minimal connection section',
      (tester) async {
    // §13.1/§13.3: the phone's connection surface is a page-level dot-map
    // stage (no card shell), an independent node row card and a bare routing
    // segment. The metrics card never existed on the phone (it is a desktop
    // surface the mockup carried over) and the plan card left the connection
    // page; the desktop workspace keeps both surfaces (端分治, §13.4) and is
    // covered by the geometry tests above and the plan countdown test below.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = VisualV3Controller(AppPage.dashboard);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    // A framed map shows the current node's approximate country position.
    // The primary phone connection action is a wide capsule, not a circle.
    expect(tester.getRect(find.byKey(kConnectActionCardKey)).height, 375);
    expect(find.descendant(of: find.byKey(kConnectActionCardKey),
        matching: find.byKey(const ValueKey('v3-map-country-marker'))),
        findsOneWidget);
    expect(find.byKey(const ValueKey('v3-mobile-connect-pill')),
        findsOneWidget);
    final capsule = tester.getRect(
        find.byKey(const ValueKey('v3-mobile-connect-pill')));
    expect(capsule.width, greaterThan(250));
    expect(capsule.width, greaterThan(capsule.height));
    expect(find.text('保护中'), findsOneWidget);
    expect(find.text('01:26:18'), findsOneWidget);
    expect(find.text('断开连接'), findsOneWidget);
    // Connected, so the timer's speed suffix shows (aqua up, green down)...
    expect(find.text('↑ 3.0 MB/s'), findsOneWidget);
    expect(find.text('↓ 12.0 MB/s'), findsOneWidget);
    // ...and the metrics card the suffix replaces stays gone.
    expect(find.text('下载速度'), findsNothing);
    expect(find.text('上传速度'), findsNothing);
    expect(find.text('本次流量'), findsNothing);
    expect(find.text('活动连接'), findsNothing);
    // The plan card has left the connection page on the phone.
    expect(find.text('我的套餐'), findsNothing);

    // Map → routing capsule → daily usage → node shortcut, with no duplicate
    // marketing hero or desktop-only transfer cards.
    final map = tester.getRect(find.byKey(kConnectActionCardKey));
    final routing = tester.getRect(
      find.byKey(const ValueKey('v3-route-mode-track')));
    final usage = tester.getRect(
      find.byKey(const ValueKey('v3-mobile-daily-usage')));
    final nodeCard = tester.getRect(find.byKey(kCurrentNodeCardKey));
    expect(map.bottom, lessThanOrEqualTo(routing.top));
    expect(routing.bottom, lessThanOrEqualTo(usage.top));
    expect(usage.bottom, lessThanOrEqualTo(nodeCard.top));
    expect(find.text('今日已用'), findsOneWidget);
    expect(find.text('2.48 GB'), findsOneWidget);
    expect(find.text('剩余流量'), findsOneWidget);
    expect(find.text('383.6 GB'), findsOneWidget);
    expect(find.text('切换节点'), findsNothing);
    expect(find.text('路由模式'), findsNothing);
    expect(find.text('代理模式'), findsNothing);
    expect(find.text('系统代理'), findsNothing);
    expect(find.text('TUN 模式'), findsNothing);
    expect(find.text('规则'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Selecting the node card now routes to the Nodes tab instead
    // of opening the old picker overlay. Navigation is covered in the
    // shell reachability tests; this fixture has no mutable page routing.
    await tester.tap(find.text('日本 东京 · Premium'));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

}

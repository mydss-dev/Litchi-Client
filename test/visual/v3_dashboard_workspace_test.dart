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

class _ConnectingFixture extends VisualV3Controller {
  _ConnectingFixture() : super(AppPage.dashboard);

  @override
  ConnectionStatus get connectionStatus => ConnectionStatus.connecting;
}

/// Starts disconnected and flips through the real state machine so the
/// strip's transitions and the 30s re-probe can be driven from a test.
class _MutableStatusFixture extends VisualV3Controller {
  _MutableStatusFixture() : super(AppPage.dashboard);

  ConnectionStatus state = ConnectionStatus.disconnected;
  int probes = 0;

  @override
  ConnectionStatus get connectionStatus => state;

  @override
  bool get coreRunning => state == ConnectionStatus.connected;

  /// Public transition helper — notifyListeners is @protected.
  void become(ConnectionStatus next) {
    state = next;
    notifyListeners();
  }
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
        // The reachability strip is a desktop presentation.
        expect(find.byKey(const ValueKey('v3-connectivity-strip')),
            findsNothing);
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
      if (target.name == 'ChatGPT') {
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

    // The probe now runs automatically on mount (post-frame): there is no
    // refresh control left to tap. One extra pump flushes the futures.
    await tester.pump();

    expect(find.text('12 ms'), findsOneWidget);
    expect(find.text('40 ms'), findsNWidgets(2));
    expect(find.text('不通'), findsOneWidget);
    // Regression guard: the manual refresh control is gone for good.
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
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

    // The strip is always four live slots — offline it shows the red
    // 未连接 state instead of a grey hint line.
    final strip = find.byKey(const ValueKey('v3-connectivity-strip'));
    expect(find.text('连接后可检测各站点连通性'), findsNothing);
    expect(find.descendant(of: strip, matching: find.text('未连接')),
        findsNWidgets(4));
    expect(find.descendant(of: strip, matching: find.textContaining('ms')),
        findsNothing);
    expect(find.descendant(of: strip, matching: find.text('检测中')),
        findsNothing);
    // The brand icons are the always-visible marks — offline included.
    // The dot is the lamp; the icons themselves never change color.
    for (final icon in [
      Icons.public_rounded,
      Icons.play_circle_fill_rounded,
      Icons.code_rounded,
      Icons.auto_awesome_rounded,
    ]) {
      expect(find.descendant(of: strip, matching: find.byIcon(icon)),
          findsOneWidget, reason: '$icon must stay visible offline');
    }
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('android merges connection, node and routing into one card',
      (tester) async {
    // Android's VPN stack has no system-proxy alternative, so the single-
    // option network selector disappears along with its group label, and the
    // node row becomes tappable with a chevron instead of a switch button.
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

    expect(find.text('代理模式'), findsNothing);
    expect(find.text('系统代理'), findsNothing);
    expect(find.text('TUN 模式'), findsNothing);
    expect(find.text('切换节点'), findsNothing);
    // The merged card speaks for itself: no routing label either.
    expect(find.text('路由模式'), findsNothing);
    expect(find.text('规则'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // The whole node row opens the picker.
    await tester.tap(find.text('日本 东京 · Premium'));
    await tester.pumpAndSettle();
    expect(find.text('搜索节点'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('connecting strip shows the amber checking state',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _ConnectingFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    final strip = find.byKey(const ValueKey('v3-connectivity-strip'));
    expect(find.descendant(of: strip, matching: find.text('检测中')),
        findsNWidgets(4));
    expect(find.descendant(of: strip, matching: find.text('未连接')),
        findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('strip goes red offline, live on connect, re-probes on cadence',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _MutableStatusFixture();
    addTearDown(controller.disposeVisual);
    // Count probe runs: every _runCheck fires one probe per site.
    var probeRuns = 0;
    ConnectivityCheckService.override = (target) async {
      probeRuns++;
      return const ConnectivityResult(ok: true, latencyMs: 21);
    };
    addTearDown(() => ConnectivityCheckService.override = null);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    await tester.pump();

    // Offline: four red slots and nothing has probed.
    final strip = find.byKey(const ValueKey('v3-connectivity-strip'));
    expect(find.descendant(of: strip, matching: find.text('未连接')),
        findsNWidgets(4));
    expect(probeRuns, 0);

    // Connecting: every slot flips to the amber checking state. The second
    // pump lets the 160ms cross-fade retire the outgoing red texts.
    controller.become(ConnectionStatus.connecting);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: strip, matching: find.text('未连接')),
        findsNothing);
    expect(find.descendant(of: strip, matching: find.text('检测中')),
        findsNWidgets(4));

    // Connected: the automatic probe runs and results land.
    controller.become(ConnectionStatus.connected);
    await tester.pump();
    await tester.pump();
    expect(probeRuns, 4);
    expect(find.text('21 ms'), findsNWidgets(4));

    // The cadence re-probe keeps the strip fresh with no manual control.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
    expect(probeRuns, 8);
    expect(find.text('21 ms'), findsNWidgets(4));
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}

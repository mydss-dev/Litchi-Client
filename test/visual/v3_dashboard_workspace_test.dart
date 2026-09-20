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
    expect(active.style?.fontWeight, FontWeight.w800);
    expect(inactive.style?.fontWeight, FontWeight.w500);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}

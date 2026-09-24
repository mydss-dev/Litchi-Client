import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

import 'v3_visual_fixture.dart';

void main() {
  testWidgets('dashboard has no redundant heading and shows notice title only', (
    tester,
  ) async {
    // Desktop heading structure; phones merge the node row into one card.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = VisualV3Controller(AppPage.dashboard);
    addTearDown(controller.disposeVisual);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(),
          home: const Scaffold(body: V3DashboardPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(V3PageHeader), findsNothing);
    expect(find.text('连接中心'), findsNothing);
    expect(find.text('当前节点'), findsOneWidget);
    // Connection state has one home: the orb button. The connection card's
    // corner badge speaks protection instead of echoing 「已连接」, and the
    // node card carries no status badge at all.
    expect(find.descendant(of: find.byKey(kConnectActionCardKey),
      matching: find.text('保护中')), findsOneWidget);
    expect(find.text('已连接'), findsNothing);
    expect(find.text('服务公告'), findsOneWidget);
    expect(find.textContaining('香港、日本线路已完成优化'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });
}

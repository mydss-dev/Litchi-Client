import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

import 'v3_visual_fixture.dart';

void main() {
  testWidgets('dashboard has no redundant heading and keeps original notices', (
    tester,
  ) async {
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
    expect(find.text('已连�?), findsOneWidget);
    expect(find.textContaining('服务公告  ·  香港、日本线路已完成优化'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

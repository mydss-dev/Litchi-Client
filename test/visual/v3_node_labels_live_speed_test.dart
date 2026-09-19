import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _TaggedFixture extends VisualV3Controller {
  _TaggedFixture(super.visualPage);

  @override
  NodeModel get currentNode =>
      super.currentNode.copyWith(tags: const ['流媒体解锁', '家宽']);

  @override
  List<NodeModel> get nodes => [currentNode, ...super.nodes.skip(1)];
}

void main() {
  testWidgets('backend node tags appear on the dashboard and overview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _TaggedFixture(AppPage.dashboard);
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
    expect(find.text('流媒体解锁'), findsOneWidget);
    expect(find.text('家宽'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(
          theme: V3Theme.light(),
          home: const Scaffold(body: V3NodesPage()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('流媒体解锁'), findsOneWidget);
    expect(find.text('家宽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live transfer rates follow the core notifiers', (tester) async {
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
    controller.downBpsNotifier.value = 1024 * 1024;
    controller.upBpsNotifier.value = 2048;
    await tester.pump();
    expect(find.text('1.0 MB/s'), findsOneWidget);
    expect(find.text('2 KB/s'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

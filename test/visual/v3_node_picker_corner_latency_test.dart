import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';
import 'package:litchi_client/shared/theme/app_icons.dart';

/// The picker and desktop overview share an outline bolt before testing,
/// and the same tier-coloured capsule as the phone after measuring.
/// Testing remains independent of selecting a node.
void main() {
  testWidgets('rows show millisecond values without duplicate status badges', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(
      MaterialApp(
        theme: V3Theme.light(),
        home: AppScope(
          controller: controller,
          child: const Scaffold(body: V3NodePicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('42ms'), findsOneWidget);
    expect(find.text('128ms'), findsOneWidget);
    expect(find.text('42MS'), findsNothing);
    expect(find.text('未测速'), findsNothing);
    expect(find.text('超时'), findsNothing);

    // The 「当前」 pill no longer sits on the current node's name line.
    expect(find.text('当前'), findsNothing);
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('valid latencies show capsules; missing bolts and timeout warning',
      (tester) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);

    for (final latency in [0, -1, 80, 350, 9999]) {
      final node = NodeModel(
        id: 'tier',
        name: '阈值节点',
        flag: '',
        code: 'TT',
        englishName: 'Tier Node',
        latency: latency,
        region: NodeRegion.asia,
      );
      var testCalls = 0;
      var rowCalls = 0;
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(
          body: V3NodeRow(
            node: node,
            controller: controller,
            onTap: () => rowCalls++,
            onTest: () => testCalls++,
            busy: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('v3-node-latency-tier'));
      expect(action, findsOneWidget);
      if (latency <= 0) {
        expect(find.descendant(of: action,
          matching: find.byIcon(AppIcons.zap)), findsOneWidget);
        expect(find.text('超时'), findsNothing);
      } else {
        expect(find.descendant(of: action,
          matching: find.byIcon(AppIcons.zap)), findsNothing);
        expect(find.text(latency >= 9999 ? '超时' : '${latency}ms'),
          findsOneWidget);
      }
      await tester.tap(action);
      await tester.pump();
      expect(testCalls, 1);
      expect(rowCalls, 0, reason: 'latency tap must not switch nodes');
    }
  });

  testWidgets('desktop rows leave out the chevron; touch rows keep it', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    const node = NodeModel(
      id: 'xx-01',
      name: '测试节点',
      flag: '',
      code: 'XX',
      englishName: 'Test Node',
      latency: 42,
      region: NodeRegion.asia,
    );

    Widget row() => Scaffold(
      body: V3NodeRow(
        node: node,
        controller: controller,
        onTap: () {},
        busy: false,
      ),
    );

    // Windows (unselected row): no trailing chevron.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(MaterialApp(theme: V3Theme.light(), home: row()));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);

    // Android: the chevron is a touch-platform affordance.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(MaterialApp(theme: V3Theme.light(), home: row()));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.chevronRight), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
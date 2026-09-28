import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

/// V3NodeRow now shows one latency readout everywhere: a colored dot plus the
/// value, vertically centered against the row's right edge. The old corner
/// badge («42MS» on the name line) and the 「当前」 pill are gone, so the
/// picker, the nodes overview, and the narrow-screen sheet all share this one
/// tail grammar driven by the shared per-region tier scale.
void main() {
  testWidgets('rows show the centered dot+value tail, not a name-line badge', (
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

    // The tail uses the lower-case grammar; the badge's 42MS is gone.
    expect(find.text('42ms'), findsOneWidget);
    expect(find.text('128ms'), findsOneWidget);
    expect(find.text('42MS'), findsNothing);

    // The 「当前」 pill no longer sits on the current node's name line.
    expect(find.text('当前'), findsNothing);
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('the tail colour reads the per-region tier scale', (tester) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    final p = V3Palette.light;
    // (region, latency, expected ink) — the shared scale behind the tail.
    final cases = <(NodeRegion, int, Color)>[
      (NodeRegion.asia, 80, p.successInk),
      (NodeRegion.asia, 150, p.warningInk),
      (NodeRegion.asia, 250, p.dangerInk),
      (NodeRegion.america, 180, p.successInk),
      (NodeRegion.america, 300, p.warningInk),
      (NodeRegion.america, 400, p.dangerInk),
      (NodeRegion.europe, 200, p.successInk),
      (NodeRegion.europe, 300, p.warningInk),
      (NodeRegion.europe, 450, p.dangerInk),
      (NodeRegion.oceania, 180, p.successInk),
      (NodeRegion.oceania, 350, p.dangerInk),
      (NodeRegion.asia, 9999, p.dangerInk),
      (NodeRegion.asia, 0, p.inkMuted),
    ];
    for (final (region, latency, expected) in cases) {
      final node = NodeModel(
        id: 'tier',
        name: '阈值节点',
        flag: '',
        code: 'TT',
        englishName: 'Tier Node',
        latency: latency,
        region: region,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: V3Theme.light(),
          home: Scaffold(
            body: V3NodeRow(
              node: node,
              controller: controller,
              onTap: () {},
              busy: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = latency >= 9999
          ? '超时'
          : latency <= 0
          ? '未测速'
          : '${latency}ms';
      final color = tester.widget<Text>(find.text(label)).style!.color!;
      expect(
        color,
        expected,
        reason: '$region ${latency}ms should tier to $expected',
      );
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
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);

    // Android: the chevron is a touch-platform affordance.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(MaterialApp(theme: V3Theme.light(), home: row()));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
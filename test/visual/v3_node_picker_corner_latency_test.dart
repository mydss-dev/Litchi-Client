import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_picker.dart';

import 'v3_visual_fixture.dart';

/// The picker's corner latency: the readout rides the name line's top-right
/// as 「延迟：32ms」, while the shared row keeps its old centered tail for
/// the nodes overview, which did not sign up for the corner style.
void main() {
  testWidgets(
    'picker rows show the 延迟：xxms readout on the name line top-right',
    (tester) async {
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

      // Every fixture node has a measured latency, so the corner shows values
      // (42 / 31 / 66 / 128 in the fixture) inside the status badge, which
      // upper-cases its label like every badge in the app.
      expect(find.text('42MS'), findsOneWidget);
      expect(find.text('128MS'), findsOneWidget);
      expect(find.text('42ms'), findsNothing);

      // The badge shares the name's line and anchors at the row's top-right.
      final name = tester.getRect(find.text('日本 东京 · Premium'));
      final badge = tester.getRect(find.text('42MS'));
      expect(
        (badge.top + badge.height / 2 - (name.top + name.height / 2)).abs(),
        lessThan(2),
        reason: 'the latency badge must sit on the name line',
      );
      expect(badge.left, greaterThan(name.right));

      // The badge color follows the latency: 42ms green, 128ms amber.
      Color badgeColor(String label) {
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(Container),
          ).first,
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      final p = V3Palette.light;
      expect(badgeColor('42MS'), p.success.withValues(alpha: 0.12));
      // 128ms to Los Angeles clears America's 200ms fast bar — green, which
      // is the whole point of the per-region tiers.
      expect(badgeColor('128MS'), p.success.withValues(alpha: 0.12));
    },
  );

  testWidgets(
    'the shared row keeps the centered tail when the flag is off',
    (tester) async {
      final controller = VisualV3Controller(AppPage.nodes);
      addTearDown(controller.disposeVisual);
      const untested = NodeModel(
        id: 'xx-01',
        name: '测试节点',
        flag: '',
        code: 'XX',
        englishName: 'Test Node',
        latency: 0,
        region: NodeRegion.asia,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: V3Theme.light(),
          home: Scaffold(
            body: V3NodeRow(
              node: untested,
              controller: controller,
              onTap: () {},
              busy: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The nodes overview's default path still renders the old label set.
      expect(find.text('未测速'), findsOneWidget);
      expect(find.text('--'), findsNothing);
    },
  );

  testWidgets('corner badge colour follows per-region latency tiers', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    final p = V3Palette.light;
    final cases = <(NodeRegion, int, Color)>[
      (NodeRegion.asia, 80, p.success),
      (NodeRegion.asia, 150, p.warning),
      (NodeRegion.asia, 250, p.danger),
      (NodeRegion.america, 180, p.success),
      (NodeRegion.america, 300, p.warning),
      (NodeRegion.america, 400, p.danger),
      (NodeRegion.europe, 200, p.success),
      (NodeRegion.europe, 300, p.warning),
      (NodeRegion.europe, 450, p.danger),
      (NodeRegion.oceania, 180, p.success),
      (NodeRegion.oceania, 350, p.danger),
      (NodeRegion.asia, 9999, p.danger),
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
              cornerLatency: true,
              onTap: () {},
              busy: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final label = find.text(
        latency >= 9999
            ? '超时'
            : latency <= 0
            ? '--'
            : '${latency}MS',
      );
      final container = tester.widget<Container>(
        find
            .ancestor(of: label, matching: find.byType(Container))
            .first,
      );
      final color = (container.decoration! as BoxDecoration).color!;
      expect(
        color,
        expected.withValues(alpha: 0.12),
        reason: '$region ${latency}ms should tier to $expected',
      );
    }
  });

  testWidgets('node rows (nodes overview tail) read the shared tier scale too', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    final p = V3Palette.light;
    Future<Color> tailColor(int latency) async {
      final node = NodeModel(
        id: 'tail',
        name: '列表节点',
        flag: '',
        code: 'TL',
        englishName: 'List Node',
        latency: latency,
        region: NodeRegion.asia,
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
      final label = latency >= 9999 ? '超时' : '${latency}ms';
      return tester.widget<Text>(find.text(label)).style!.color!;
    }

    expect(await tailColor(80), p.successInk);
    expect(await tailColor(150), p.warningInk);
    // 250ms in Asia is outright slow now, and a timeout is red — both used to
    // collapse into the same grey as untested.
    expect(await tailColor(250), p.dangerInk);
    expect(await tailColor(9999), p.dangerInk);
  });

  testWidgets('narrow screens swap the corner badge for the tail by the chevron', (
    tester,
  ) async {
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(controller.disposeVisual);
    const node = NodeModel(
      id: 'jp-01',
      name: '日本 东京 · Premium',
      flag: '',
      code: 'JP',
      englishName: 'Tokyo',
      latency: 42,
      region: NodeRegion.asia,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(
          body: V3NodeRow(
            node: node,
            controller: controller,
            cornerLatency: true,
            onTap: () {},
            busy: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Phone width: the corner badge stands down and the bare tail value
    // rides left of the chevron — the nodes overview's exact grammar.
    expect(find.text('42ms'), findsOneWidget);
    expect(find.text('42MS'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

/// Nodes overview UX: the latency-tier filter and multi-select latency
/// testing. The tier chips reuse the region-aware [v3LatencyTierIndex] scale
/// that paints the row badges, so a chip's count and the badges can never
/// disagree about what counts as fast.
class _NodesFixture extends VisualV3Controller {
  _NodesFixture() : super(AppPage.nodes);

  Set<String>? lastIds;
  int selections = 0;

  @override
  List<NodeModel> get nodes => const [
    NodeModel(
      id: 'fast',
      name: '香港 · 快线',
      flag: '',
      code: 'HK',
      englishName: 'HK Fast',
      latency: 40,
      region: NodeRegion.asia,
    ),
    NodeModel(
      id: 'okay',
      name: '新加坡 · 标准',
      flag: '',
      code: 'SG',
      englishName: 'SG Okay',
      latency: 150,
      region: NodeRegion.asia,
    ),
    NodeModel(
      id: 'slow',
      name: '美国 · 慢线',
      flag: '',
      code: 'US',
      englishName: 'US Slow',
      latency: 400,
      region: NodeRegion.america,
    ),
    NodeModel(
      id: 'timeout',
      name: '德国 · 超时线',
      flag: '',
      code: 'DE',
      englishName: 'DE Timeout',
      latency: 9999,
      region: NodeRegion.europe,
    ),
  ];

  @override
  Future<bool> testLatencies({Set<String>? ids}) async {
    lastIds = ids;
    return true;
  }

  @override
  Future<String?> setCurrentNode(NodeModel node) async {
    selections++;
    return null;
  }
}

Future<void> _pump(WidgetTester tester, _NodesFixture controller) async {
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(
      theme: V3Theme.light(),
      home: const Scaffold(body: V3NodesPage()),
    ),
  ));
  await tester.pump();
}

void main() {
  // Node rows live in a scrollable list; rows below the fold must be scrolled
  // into view before a tap lands on them.
  Future<void> toggleRow(WidgetTester tester, String name) async {
    await tester.ensureVisible(find.text(name));
    await tester.pump();
    await tester.tap(find.text(name));
    await tester.pump();
  }

  testWidgets('latency tier chips count and filter on the shared scale',
      (tester) async {
    final controller = _NodesFixture();
    await _pump(tester, controller);
    // One node per tier: the counts read straight off the same region-aware
    // scale the badges paint (asia clears 快 at ≤100, 良 at ≤200; america is
    // more forgiving, so the 400ms US node is the lone 慢).
    expect(find.text('快 1'), findsOneWidget);
    expect(find.text('良 1'), findsOneWidget);
    expect(find.text('慢 1'), findsOneWidget);
    expect(find.text('超时 1'), findsOneWidget);

    // 超时 keeps only the timed-out node; 全部延迟 brings everything back.
    await tester.tap(find.byKey(const ValueKey('v3-tier-timeout')));
    await tester.pump();
    expect(find.text('德国 · 超时线'), findsOneWidget);
    expect(find.text('香港 · 快线'), findsNothing);
    expect(find.text('共 1 个'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v3-tier-all')));
    await tester.pump();
    expect(find.text('香港 · 快线'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection mode batches a latency test by ids', (tester) async {
    final controller = _NodesFixture();
    await _pump(tester, controller);
    expect(find.byKey(const Key('v3-nodes-select-bar')), findsNothing);

    await tester.tap(find.byKey(const Key('v3-nodes-select-mode')));
    await tester.pump();
    expect(find.byKey(const Key('v3-nodes-select-bar')), findsOneWidget);
    expect(find.text('已选 0'), findsOneWidget);
    // Zero selected keeps the batch button inert.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('v3-nodes-test-selected')),
          )
          .onPressed,
      isNull,
    );

    // Rows toggle membership: two taps, two members.
    await toggleRow(tester, '香港 · 快线');
    await toggleRow(tester, '新加坡 · 标准');
    expect(find.text('已选 2'), findsOneWidget);

    // 全选 adds the currently filtered list; 清空 empties it again.
    await tester.tap(find.byKey(const Key('v3-nodes-select-all')));
    await tester.pump();
    expect(find.text('已选 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v3-nodes-clear-selection')));
    await tester.pump();
    expect(find.text('已选 0'), findsOneWidget);

    // A fresh pair runs the batch with exactly those ids.
    await toggleRow(tester, '香港 · 快线');
    await toggleRow(tester, '德国 · 超时线');
    expect(find.text('测速 2 个'), findsOneWidget);
    await tester.tap(find.byKey(const Key('v3-nodes-test-selected')));
    await tester.pump();
    expect(controller.lastIds, {'fast', 'timeout'});
    expect(tester.takeException(), isNull);

    // Exiting selection clears the set — no stale members next time. The
    // toolbar button scrolled out of view during the row taps.
    await tester.ensureVisible(find.byKey(const Key('v3-nodes-select-mode')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('v3-nodes-select-mode')));
    await tester.pump();
    expect(find.byKey(const Key('v3-nodes-select-bar')), findsNothing);
    await tester.tap(find.byKey(const Key('v3-nodes-select-mode')));
    await tester.pump();
    expect(find.text('已选 0'), findsOneWidget);
  });

  testWidgets('selection taps never switch nodes', (tester) async {
    final controller = _NodesFixture();
    await _pump(tester, controller);
    await tester.tap(find.byKey(const Key('v3-nodes-select-mode')));
    await tester.pump();
    // In selection mode the row's own switch action stands down; tapping a
    // row toggles membership only.
    await toggleRow(tester, '香港 · 快线');
    expect(controller.selections, 0);
    expect(find.text('已选 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

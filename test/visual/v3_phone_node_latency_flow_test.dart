import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';
import 'package:litchi_client/shared/theme/app_icons.dart';

class _PhoneLatencyFixture extends VisualV3Controller {
  _PhoneLatencyFixture() : super(AppPage.nodes);

  final Completer<void> resultReady = Completer<void>();
  Set<String>? requestedIds;
  bool measured = false;

  @override
  List<NodeModel> get nodes => [
    NodeModel(id: 'untested', name: '日本 · 待测速', flag: '',
      code: 'JP', englishName: 'Japan', latency: measured ? 80 : 0,
      region: NodeRegion.asia),
    const NodeModel(id: 'medium', name: '新加坡 · 标准', flag: '',
      code: 'SG', englishName: 'Singapore', latency: 150,
      region: NodeRegion.asia),
    const NodeModel(id: 'slow', name: '美国 · 慢线', flag: '',
      code: 'US', englishName: 'United States', latency: 400,
      region: NodeRegion.america),
    const NodeModel(id: 'timeout', name: '德国 · 超时', flag: '',
      code: 'DE', englishName: 'Germany', latency: 9999,
      region: NodeRegion.europe),
  ];

  @override
  Future<bool> testLatencies({Set<String>? ids}) async {
    requestedIds = ids;
    await resultReady.future;
    measured = true;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets('phone nodes show outline bolt, pending spinner, then tier pill',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _PhoneLatencyFixture();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: const Scaffold(body: V3NodesPage()),
      ),
    ));
    await tester.pump();

    final probe = find.byKey(const ValueKey('v3-node-latency-untested'));
    expect(probe, findsOneWidget);
    expect(find.descendant(of: probe,
      matching: find.byIcon(AppIcons.zap)), findsOneWidget);
    expect(tester.widget<Text>(find.text('150ms')).style?.color,
      V3Palette.light.warningInk);
    expect(tester.widget<Text>(find.text('400ms')).style?.color,
      V3Palette.light.dangerInk);
    expect(find.text('超时'), findsOneWidget);

    await tester.tap(probe);
    await tester.pump();
    expect(controller.requestedIds, {'untested'});
    expect(find.descendant(of: probe,
      matching: find.byKey(const ValueKey('v3-node-speed-loading'))),
      findsOneWidget);

    controller.resultReady.complete();
    await tester.pumpAndSettle();
    expect(find.text('80ms'), findsOneWidget);
    expect(tester.widget<Text>(find.text('80ms')).style?.color,
      V3Palette.light.successInk);
    expect(find.descendant(of: probe,
      matching: find.byIcon(AppIcons.zap)), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

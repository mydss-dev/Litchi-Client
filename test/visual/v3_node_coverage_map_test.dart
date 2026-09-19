import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_nodes_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_coverage_map.dart';

import 'v3_visual_fixture.dart';

const _hk = NodeModel(
  id: 'hk-01', name: 'HK node', flag: '', code: 'HK',
  englishName: 'Hong Kong', latency: 32, region: NodeRegion.asia,
);
const _jp = NodeModel(
  id: 'jp-01', name: 'JP node', flag: '', code: 'JP',
  englishName: 'Tokyo', latency: 45, region: NodeRegion.asia,
);
const _de = NodeModel(
  id: 'de-01', name: 'DE node', flag: '', code: 'DE',
  englishName: 'Germany', latency: 130, region: NodeRegion.europe,
);
const _unknown = NodeModel(
  id: 'zz-01', name: 'Unknown node', flag: '', code: 'ZZ',
  englishName: 'Other', latency: 0, region: NodeRegion.asia,
);
const _auto = NodeModel(
  id: 'auto', name: 'Auto', flag: '', code: '',
  englishName: 'Automatic', latency: 0, isAuto: true,
);

class _NodeFixture extends VisualV3Controller {
  _NodeFixture() : super(AppPage.nodes);
  List<NodeModel> live = [_hk, _jp, _de];

  @override
  List<NodeModel> get nodes => live;

  void replace(List<NodeModel> next) {
    live = next;
    notifyListeners();
  }
}

void main() {
  testWidgets('coverage only counts real nodes; unknown codes keep a chip',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: Scaffold(
        body: V3NodeCoverageMap(
          nodes: const [_hk, _hk, _unknown, _auto],
          selectedCode: null,
          onSelected: (_) {},
        ),
      ),
    ));
    expect(find.text('2 个地区 · 3 个节点'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-map-marker-HK')), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-map-marker-ZZ')), findsNothing);
    expect(find.byKey(const ValueKey('v3-map-country-ZZ')), findsOneWidget);
  });

  testWidgets('interactive coverage map still supports filters for other callers',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: V3NodeCoverageMap(
            nodes: const [_hk, _jp],
            selectedCode: selected,
            onSelected: (code) => setState(() => selected = code),
          ),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('v3-map-country-HK')));
    await tester.pumpAndSettle();
    expect(selected, 'HK');
    await tester.tap(find.byKey(const ValueKey('v3-map-country-all')));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('nodes overview has no map filters, selection or testing controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixture = _NodeFixture();
    addTearDown(fixture.disposeVisual);
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: AppScope(
        controller: fixture,
        child: const Scaffold(body: V3NodesPage()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('HK node'), findsOneWidget);
    expect(find.text('JP node'), findsOneWidget);
    expect(find.text('DE node'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('全部测速'), findsNothing);
    expect(find.text('自动选择'), findsNothing);
    expect(find.ancestor(of: find.text('HK node'), matching: find.byType(InkWell)),
      findsNothing);
    expect(find.byKey(const ValueKey('v3-map-marker-HK')), findsOneWidget);
    fixture.replace([_jp, _de]);
    await tester.pumpAndSettle();
    expect(find.text('HK node'), findsNothing);
    expect(find.text('JP node'), findsOneWidget);
    expect(find.text('DE node'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-map-marker-HK')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('360px map layout has no overflow in $theme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        darkTheme: V3Theme.dark(),
        themeMode: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: V3NodeCoverageMap(
              nodes: const [_hk, _jp, _de, _unknown],
              selectedCode: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('v3-map-country-HK')), findsOneWidget);
    });
  }
}

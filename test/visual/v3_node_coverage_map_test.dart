import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  test('world asset includes geographically traced coastlines', () async {
    final svg = await rootBundle.loadString('assets/images/world_coastline.svg');
    expect(svg, contains('viewBox="0 0 960 480"'));
    expect(svg, contains('<path d="M'));
  });

  test('probe colors never infer live health or offline from missing values', () {
    expect(v3NodeProbeState([_hk, _de]), V3NodeProbeState.responsive);
    expect(v3NodeProbeState([_hk.copyWith(latency: 9999),
      _de.copyWith(latency: 9999)]), V3NodeProbeState.timedOut);
    expect(v3NodeProbeState([_hk.copyWith(latency: 9999), _unknown]),
      V3NodeProbeState.unknown);
    expect(v3NodeProbeState([_hk.copyWith(latency: -1)]),
      V3NodeProbeState.unknown);
    expect(v3NodeProbeState([_auto]), V3NodeProbeState.unknown);
    expect(v3NodeProbeState([]), V3NodeProbeState.unknown);
  });

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
    await tester.pumpAndSettle();
    expect(find.text('2 个地区 · 3 个节点'), findsOneWidget);
    expect(find.text('全球节点地图'), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-map-marker-HK')), findsOneWidget);
    expect(find.byKey(const ValueKey('v3-map-marker-ZZ')), findsNothing);
    expect(find.byKey(const ValueKey('v3-map-country-ZZ')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('nodes overview wires the map filters to the node list',
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
    expect(find.byKey(const ValueKey('v3-map-marker-HK')), findsOneWidget);

    // The map's country chips filter the list below the map.
    await tester.ensureVisible(find.byKey(const ValueKey('v3-map-country-HK')));
    await tester.tap(find.byKey(const ValueKey('v3-map-country-HK')));
    await tester.pumpAndSettle();
    expect(find.text('HK node'), findsOneWidget);
    expect(find.text('JP node'), findsNothing);
    expect(find.text('DE node'), findsNothing);

    // 全部地区 clears the region filter again.
    await tester.ensureVisible(find.byKey(const ValueKey('v3-map-country-all')));
    await tester.tap(find.byKey(const ValueKey('v3-map-country-all')));
    await tester.pumpAndSettle();
    expect(find.text('JP node'), findsOneWidget);
    expect(find.text('DE node'), findsOneWidget);

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

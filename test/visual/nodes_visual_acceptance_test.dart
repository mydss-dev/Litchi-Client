import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/features/nodes/widgets/greenfield_nodes_browser.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_filter.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  const mainPaneSize = Size(700, 654); // 900x700 shell - 200 sidebar - 46 title bar.

  Future<void> pumpNodes(
    WidgetTester tester, {
    required ThemeMode themeMode,
  }) async {
    await tester.binding.setSurfaceSize(mainPaneSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: AppShellSpec.pagePaddingFor(AppPlatform.current),
            child: GreenfieldNodesBrowser(
              allNodes: _nodes,
              visibleNodes: _nodes,
              currentNode: _nodes[1],
              selectedNodeId: _nodes[1].id,
              autoSelected: false,
              favorites: const {'hk-01', 'jp-01', 'us-01'},
              selectedFilter: NodeFilterTab.all,
              testingLatencies: false,
              noPlan: false,
              onSearchChanged: (_) {},
              onFilterChanged: (_) {},
              onAutoSelect: () {},
              onSelectNode: (_) {},
              onToggleFavorite: (_) {},
              onLatencyTest: () {},
              onRefresh: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  testWidgets(
    'Windows 900x700 nodes light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpNodes(tester, themeMode: ThemeMode.light);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/nodes_light_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Windows 900x700 nodes dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await pumpNodes(tester, themeMode: ThemeMode.dark);
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/nodes_dark_main_900x700.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

const _nodes = <NodeModel>[
  NodeModel(
    id: 'hk-01',
    name: '香港 01 · Premium',
    flag: '🇭🇰',
    code: 'HK',
    englishName: 'Hong Kong',
    latency: 28,
    tags: ['AnyTLS', 'IEPL'],
    favorite: true,
    region: NodeRegion.asia,
  ),
  NodeModel(
    id: 'jp-01',
    name: '日本 东京 01',
    flag: '🇯🇵',
    code: 'JP',
    englishName: 'Tokyo',
    latency: 42,
    tags: ['VLESS', 'Premium'],
    favorite: true,
    region: NodeRegion.asia,
  ),
  NodeModel(
    id: 'sg-01',
    name: '新加坡 01',
    flag: '🇸🇬',
    code: 'SG',
    englishName: 'Singapore',
    latency: 58,
    tags: ['AnyTLS'],
    region: NodeRegion.asia,
  ),
  NodeModel(
    id: 'tw-01',
    name: '台湾 01',
    flag: '🇹🇼',
    code: 'TW',
    englishName: 'Taiwan',
    latency: 66,
    tags: ['VLESS'],
    region: NodeRegion.asia,
  ),
  NodeModel(
    id: 'us-01',
    name: '美国 洛杉矶 01',
    flag: '🇺🇸',
    code: 'US',
    englishName: 'Los Angeles',
    latency: 128,
    tags: ['Premium'],
    favorite: true,
    region: NodeRegion.america,
  ),
  NodeModel(
    id: 'de-01',
    name: '德国 法兰克福 01',
    flag: '🇩🇪',
    code: 'DE',
    englishName: 'Frankfurt',
    latency: 184,
    tags: ['VLESS'],
    region: NodeRegion.europe,
  ),
  NodeModel(
    id: 'fr-01',
    name: '法国 巴黎 01',
    flag: '🇫🇷',
    code: 'FR',
    englishName: 'Paris',
    latency: 196,
    tags: ['AnyTLS'],
    region: NodeRegion.europe,
  ),
  NodeModel(
    id: 'au-01',
    name: '澳大利亚 悉尼 01',
    flag: '🇦🇺',
    code: 'AU',
    englishName: 'Sydney',
    latency: 228,
    tags: ['Premium'],
    region: NodeRegion.oceania,
  ),
];

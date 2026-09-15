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
  Future<void> pumpNodes(
    WidgetTester tester, {
    required ThemeMode themeMode,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
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

  for (final caseData in const [
    _Case('light', ThemeMode.light, Size(390, 844), '390x844'),
    _Case('dark', ThemeMode.dark, Size(390, 844), '390x844'),
    _Case('light', ThemeMode.light, Size(360, 800), '360x800'),
    _Case('dark', ThemeMode.dark, Size(360, 800), '360x800'),
  ]) {
    testWidgets(
      'Android ${caseData.label} nodes ${caseData.themeName} visual',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await pumpNodes(
            tester,
            themeMode: caseData.themeMode,
            size: caseData.size,
          );
          await expectLater(
            find.byType(Scaffold),
            matchesGoldenFile(
              'goldens/android_nodes_${caseData.themeName}_${caseData.label}.png',
            ),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
      skip: !_visualSnapshotsEnabled,
    );
  }
}

class _Case {
  const _Case(this.themeName, this.themeMode, this.size, this.label);

  final String themeName;
  final ThemeMode themeMode;
  final Size size;
  final String label;
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

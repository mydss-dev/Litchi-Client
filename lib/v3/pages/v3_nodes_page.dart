import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_latency_tier.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_groups.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_toast.dart';

/// The node overview: search, filter by region and latency tier, multi-select
/// nodes for a targeted latency test, and switch. It is the deep-dive view
/// over the same controller state as the dashboard's quick switcher, so the
/// two stay in sync — the overview is where you browse carefully, the
/// dashboard is where you connect.
class V3NodesPage extends StatefulWidget {
  const V3NodesPage({super.key});

  @override
  State<V3NodesPage> createState() => _V3NodesPageState();
}

class _V3NodesPageState extends State<V3NodesPage> {
  // The clear-filters action must empty the visible field too, not just the
  // query state -- an uncontrolled field would keep showing what the list no
  // longer filters by.
  final _queryCtrl = TextEditingController();
  String _query = '';
  String? _region;
  bool _latencyFirst = false;
  String? _pending;
  // Multi-select latency testing: while on, tapping rows toggles membership
  // in [_selectedIds] instead of switching nodes; exiting clears the set.
  bool _selecting = false;
  final Set<String> _selectedIds = {};
  // Latency-tier filter: null shows everything, otherwise 'fast' | 'okay' |
  // 'slow' | 'timeout' — the same region-aware scale the badges paint, so a
  // 快 filter and a green badge can never disagree.
  String? _tier;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _testLatencies({Set<String> ids = const {}}) async {
    final controller = AppScope.read(context);
    if (controller.isLatencyTesting) return;
    if (ids.isEmpty && controller.nodes.isEmpty) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final failureText = v3Copy(
      context,
      zh: '测速失败或所有节点超时',
      en: 'Test failed or all nodes timed out',
      tw: '測速失敗或所有節點逾時',
    );
    final ok = await controller.testLatencies(ids: ids.isEmpty ? null : ids);
    if (!ok && mounted) {
      V3Toast.showInOverlay(overlay, failureText, type: V3ToastType.warning);
    }
  }

  Future<void> _select(
    String id,
    Future<String?> Function() action,
    String success,
  ) async {
    if (_pending != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    // Resolve locale before awaiting. A failed request must not use a stale context.
    final failureMessage = v3Copy(
      context,
      zh: '操作失败，请检查网络后重试。',
      en: 'Operation failed. Check your network and retry.',
      tw: '操作失敗，請檢查網路後重試。',
    );
    setState(() => _pending = id);
    String? error;
    try {
      error = await action();
    } catch (_) {
      error = failureMessage;
    }
    if (!mounted) return;
    // Root overlay outlives any navigation, so feedback stays visible.
    V3Toast.showInOverlay(
      overlay,
      error ?? success,
      type: error == null ? V3ToastType.success : V3ToastType.error,
    );
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final groups = v3GroupNodesByCountry(controller.nodes);
    final activeRegion = _region != null && groups.containsKey(_region)
        ? _region
        : null;
    final query = _query.trim().toLowerCase();
    final all = controller.nodes.where((node) => !node.isAuto).toList();
    // Region + search first; the tier chips count against that candidate set,
    // so a chip's number answers "how many of what I see would this keep".
    var nodes = all
        .where(
          (node) =>
              (_region == null || node.code.trim().toUpperCase() == _region) &&
              (query.isEmpty ||
                  node.name.toLowerCase().contains(query) ||
                  node.englishName.toLowerCase().contains(query) ||
                  node.code.toLowerCase().contains(query) ||
                  node.tags.any((tag) => tag.toLowerCase().contains(query))),
        )
        .toList();
    int tierCount(String tier) {
      if (tier == 'timeout') {
        return nodes.where((node) => node.latency >= 9999).length;
      }
      final want = switch (tier) {
        'fast' => 0,
        'okay' => 1,
        _ => 2,
      };
      return nodes
          .where(
            (node) => v3LatencyTierIndex(node.region, node.latency) == want,
          )
          .length;
    }

    if (_tier != null) {
      final tier = _tier!;
      nodes = nodes.where((node) {
        if (tier == 'timeout') return node.latency >= 9999;
        final want = switch (tier) {
          'fast' => 0,
          'okay' => 1,
          _ => 2,
        };
        return v3LatencyTierIndex(node.region, node.latency) == want;
      }).toList();
    }
    if (_latencyFirst) {
      int rank(int latency) => latency > 0 && latency < 9999
          ? latency
          : latency >= 9999
          ? 9999
          : 10000;
      nodes.sort((a, b) => rank(a.latency).compareTo(rank(b.latency)));
    }
    // Two scroll zones on desktop: the filters hold still while the node
    // list scrolls under them, so a chip tap re-filters the rows already in
    // view. One shared page scroll left only ~4 rows visible at the 900x700
    // floor under ~310px of chrome, and every filter change needed a scroll
    // back to the top. Phones keep the single page scroll.
    final filterChildren = <Widget>[
      V3PageHeader(
        title: v3Copy(context, zh: '节点概览', en: 'Node overview', tw: '節點概覽'),
        // DLSS5's "31 of 31 shown": the header counts the live fleet so
        // the page answers "how big is the network" before you scroll.
        subtitle: v3Copy(
          context,
          zh: '${all.length} 个可用节点',
          en: '${all.length} nodes available',
          tw: '${all.length} 個可用節點',
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: v3Copy(
                  context,
                  zh: '搜索节点',
                  en: 'Search nodes',
                  tw: '搜尋節點',
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('v3-nodes-select-mode'),
              onPressed: all.isEmpty
                  ? null
                  : () => setState(() {
                      _selecting = !_selecting;
                      if (!_selecting) _selectedIds.clear();
                    }),
              icon: Icon(
                _selecting
                    ? Icons.check_circle_rounded
                    : Icons.checklist_rounded,
                size: 17,
              ),
              label: Text(
                v3Copy(context, zh: '选择节点', en: 'Select', tw: '選擇節點'),
              ),
            ),
          ),
          if (!_selecting) ...[
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: const Key('v3-overview-speed-test'),
                onPressed:
                    controller.isLatencyTesting ||
                        _pending != null ||
                        controller.nodes.isEmpty
                    ? null
                    : _testLatencies,
                icon: controller.isLatencyTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed_rounded, size: 17),
                label: Text(v3Copy(context, zh: '测速', en: 'Test', tw: '測速')),
              ),
            ),
          ],
        ],
      ),
      // Region chips sit with the list they filter — and the tier chips
      // under them slice by the measured latency scale, so "fast, in
      // Hong Kong" is two taps instead of scanning every badge.
      if (groups.isNotEmpty) ...[
        const SizedBox(height: 12),
        _ChipLine(
          children: [
            ChoiceChip(
              key: const ValueKey('v3-map-country-all'),
              label: Text(
                v3Copy(context, zh: '全部地区', en: 'All regions', tw: '全部地區'),
              ),
              selected: activeRegion == null,
              showCheckmark: false,
              side: v3ChipSide(p, selected: activeRegion == null),
              onSelected: (_) => setState(() => _region = null),
            ),
            for (final code in groups.keys.toList()..sort())
              ChoiceChip(
                key: ValueKey('v3-map-country-$code'),
                label: Text(
                  '${v3NodeCountryName(context, code)} ${groups[code]!.length}',
                ),
                selected: activeRegion == code,
                showCheckmark: false,
                side: v3ChipSide(p, selected: activeRegion == code),
                onSelected: (_) => setState(
                  () => _region = activeRegion == code ? null : code,
                ),
              ),
          ],
        ),
      ],
      if (all.isNotEmpty) ...[
        const SizedBox(height: 8),
        _ChipLine(
          children: [
            ChoiceChip(
              key: const ValueKey('v3-tier-all'),
              label: Text(
                v3Copy(context, zh: '全部延迟', en: 'Any latency', tw: '全部延遲'),
              ),
              selected: _tier == null,
              showCheckmark: false,
              side: v3ChipSide(p, selected: _tier == null),
              onSelected: (_) => setState(() => _tier = null),
            ),
            for (final (tier, zh, en, tw) in const [
              ('fast', '快', 'Fast', '快'),
              ('okay', '良', 'Okay', '良'),
              ('slow', '慢', 'Slow', '慢'),
              ('timeout', '超时', 'Timeout', '逾時'),
            ])
              ChoiceChip(
                key: ValueKey('v3-tier-$tier'),
                label: Text(
                  '${v3Copy(context, zh: zh, en: en, tw: tw)}'
                  ' ${tierCount(tier)}',
                ),
                selected: _tier == tier,
                showCheckmark: false,
                side: v3ChipSide(p, selected: _tier == tier),
                onSelected: (_) =>
                    setState(() => _tier = _tier == tier ? null : tier),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Text(
              v3Copy(context, zh: '节点列表', en: 'Nodes', tw: '節點列表'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            v3Copy(
              context,
              zh: '共 ${nodes.length} 个',
              en: '${nodes.length} total',
              tw: '共 ${nodes.length} 個',
            ),
            style: TextStyle(color: p.inkMuted, fontSize: 11),
          ),
          const SizedBox(width: 12),
          ChoiceChip(
            label: Text(
              v3Copy(context, zh: '延迟优先', en: 'Fastest first', tw: '延遲優先'),
            ),
            selected: _latencyFirst,
            showCheckmark: false,
            side: v3ChipSide(p, selected: _latencyFirst),
            onSelected: (value) => setState(() => _latencyFirst = value),
          ),
        ],
      ),
      // Selection mode's action bar: the list it acts on sits right
      // below, so 已选 n / 全选 / 清空 / 测速 never drift out of view.
      if (_selecting && all.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          key: const Key('v3-nodes-select-bar'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: BorderRadius.circular(V3Radius.field),
            border: Border.all(color: p.hairline),
          ),
          child: Row(
            children: [
              Text(
                v3Copy(
                  context,
                  zh: '已选 ${_selectedIds.length}',
                  en: '${_selectedIds.length} selected',
                  tw: '已選 ${_selectedIds.length}',
                ),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                key: const Key('v3-nodes-select-all'),
                onPressed: nodes.isEmpty
                    ? null
                    : () => setState(
                        () => _selectedIds.addAll(nodes.map((n) => n.id)),
                      ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  v3Copy(context, zh: '全选', en: 'All', tw: '全選'),
                  style: TextStyle(
                    color: p.lycheeInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const Key('v3-nodes-clear-selection'),
                onPressed: _selectedIds.isEmpty
                    ? null
                    : () => setState(_selectedIds.clear),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(
                  v3Copy(context, zh: '清空', en: 'Clear', tw: '清空'),
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                key: const Key('v3-nodes-test-selected'),
                onPressed:
                    controller.isLatencyTesting ||
                        _pending != null ||
                        _selectedIds.isEmpty
                    ? null
                    : () => _testLatencies(ids: Set.of(_selectedIds)),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: p.onLychee,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                icon: controller.isLatencyTesting
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.onLychee,
                        ),
                      )
                    : const Icon(Icons.speed_rounded, size: 16),
                label: Text(
                  _selectedIds.isEmpty
                      ? v3Copy(context, zh: '测速', en: 'Test', tw: '測速')
                      : v3Copy(
                          context,
                          zh: '测速 ${_selectedIds.length} 个',
                          en: 'Test ${_selectedIds.length}',
                          tw: '測速 ${_selectedIds.length} 個',
                        ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ];
    final listChildren = <Widget>[
      const SizedBox(height: 12),
      if (controller.isInitialLoading)
        // First-load placeholders in the shape of node rows, so the loaded
        // list hands in without an empty-state flash (the tickets page's
        // loading-space rule).
        for (var i = 0; i < 3; i++) const V3NodeSkeletonRow()
      else if (controller.dataLoadError != null && all.isEmpty)
        // Failure is not emptiness: name the error and offer the retry.
        V3EmptyState(
          icon: Icons.error_outline_rounded,
          title: v3Copy(context, zh: '节点加载失败', en: 'Could not load nodes',
            tw: '節點載入失敗'),
          subtitle: controller.dataLoadError!,
          actionLabel: v3Copy(context, zh: '重试', en: 'Retry', tw: '重試'),
          onAction: controller.refreshData,
        )
      else if (all.isEmpty)
        V3EmptyState(
          icon: Icons.public_off_rounded,
          title: v3Copy(context, zh: '暂无节点', en: 'No nodes yet', tw: '暫無節點'),
          subtitle: v3Copy(
            context,
            zh: '刷新订阅后，节点会出现在这里。',
            en: 'Refresh your subscription and they will appear here.',
            tw: '重新整理訂閱後，節點會顯示在這裡。',
          ),
          actionLabel: v3Copy(context, zh: '刷新订阅', en: 'Refresh', tw: '重新整理訂閱'),
          onAction: controller.refreshData,
        )
      else ...[
        // The auto route is not a measurable node: in selection mode it
        // stands down instead of pretending to join the batch.
        // Screen readers cannot read the active route from the tint alone:
        // the auto row announces as selected, and as a button while tapping
        // it can switch (mirrors V3AutoRouteRow's own `active` flag).
        Semantics(
          container: true,
          selected: controller.autoSelected,
          button: !(_selecting || _pending != null || controller.autoSelected),
          child: V3AutoRouteRow(
            controller: controller,
            busy: _pending == 'auto',
            onTap: _selecting || _pending != null || controller.autoSelected
                ? null
                : () => _select(
                    'auto',
                    controller.selectAuto,
                    v3Copy(
                      context,
                      zh: '已选择自动节点，请在连接页确认连接状态。',
                      en: 'Automatic node selected. Confirm your connection on the connection page.',
                      tw: '已選擇自動節點，請至連線頁確認連線狀態。',
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        if (nodes.isEmpty)
          V3EmptyState(
            icon: Icons.search_off_rounded,
            title: v3Copy(
              context,
              zh: '没有匹配的节点',
              en: 'No matching nodes',
              tw: '沒有符合的節點',
            ),
            subtitle: v3Copy(
              context,
              zh: '换个关键词，或清空搜索和地区筛选。',
              en: 'Try another keyword, or clear the search and region filter.',
              tw: '換個關鍵詞，或清空搜尋和地區篩選。',
            ),
            actionLabel: v3Copy(
              context,
              zh: '清空筛选',
              en: 'Clear filters',
              tw: '清空篩選',
            ),
            onAction: () {
              _queryCtrl.clear();
              setState(() {
                _query = '';
                _region = null;
                _tier = null;
              });
            },
          )
        else
          for (final node in nodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _selecting
                  // Selection mode: the row's own tap is disabled and the
                  // whole strip — check circle included — toggles
                  // membership instead of switching nodes.
                  ? _SelectionRow(
                      selected: _selectedIds.contains(node.id),
                      onTap: () => setState(() {
                        _selectedIds.contains(node.id)
                            ? _selectedIds.remove(node.id)
                            : _selectedIds.add(node.id);
                      }),
                      child: V3NodeRow(
                        node: node,
                        controller: controller,
                        busy: _pending == node.id,
                        onTap: null,
                      ),
                    )
                  : Semantics(
                      // Same color-only problem: expose the active node as
                      // the selected option and a tappable row as a button.
                      // Both mirror V3NodeRow's own `selected` tint logic and
                      // this onTap guard.
                      container: true,
                      selected: !controller.autoSelected &&
                          controller.currentNode.id == node.id,
                      button: !(_pending != null ||
                          (!controller.autoSelected &&
                              controller.currentNode.id == node.id)),
                      child: V3NodeRow(
                        node: node,
                        controller: controller,
                        busy: _pending == node.id,
                        onTap:
                            _pending != null ||
                                (!controller.autoSelected &&
                                    controller.currentNode.id == node.id)
                            ? null
                            : () => _select(
                                node.id,
                                () => controller.setCurrentNode(node),
                                v3Copy(
                                  context,
                                  zh: '已选择 ${node.name}，请在连接页确认连接状态。',
                                  en: '${node.name} selected. Confirm your connection on the connection page.',
                                  tw: '已選擇 ${node.name}，請至連線頁確認連線狀態。',
                                ),
                              ),
                      ),
                    ),
            ),
      ],
    ];
    return LayoutBuilder(
      builder: (context, pane) {
        // Desktop: the filter chrome never scrolls away, the list scrolls in
        // its own region under it. Compact keeps the single page scroll.
        if (pane.maxWidth >= V3Layout.paneCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: V3WaveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: filterChildren,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  child: V3WaveColumn(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: listChildren,
                  ),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: V3Layout.pageInsets,
          child: V3WaveColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [...filterChildren, ...listChildren],
          ),
        );
      },
    );
  }
}

/// A node row in selection mode: a leading check circle in the left gutter
/// (the M3 checklist grammar) and the whole strip toggles membership. The
/// filled circle uses the palette's lychee + onLychee pair, the hollow one a
/// hairline ring, so checked and unchecked never swap shape language.
class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.selected,
    required this.onTap,
    required this.child,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final row = V3Pressable(
      borderRadius: BorderRadius.circular(V3Radius.card),
      hoverTint: p.ink.withValues(alpha: 0.08),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: v3ReducedMotion(context)
                  ? Duration.zero
                  : V3Motion.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? p.lychee : Colors.transparent,
                border: Border.all(
                  color: selected ? p.lychee : p.line,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 15, color: p.onLychee)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
    // The check circle is color-only: announce the row's checked state as one
    // merged node with the node name and the tap action, so a screen reader
    // hears the toggle instead of having to infer it from the fill color.
    return Semantics(container: true, checked: selected, child: row);
  }
}

/// The two filter-chip rows. On a phone the rows don't wrap onto extra lines
/// (M3's scrollable filter-chip list): one tappable line each, swipe sideways
/// to reach the rest. Desktop keeps free wrapping.
class _ChipLine extends StatelessWidget {
  const _ChipLine({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < V3Layout.paneCompact) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  children[i],
                ],
              ],
            ),
          );
        }
        return Wrap(spacing: 7, runSpacing: 7, children: children);
      },
    );
  }
}

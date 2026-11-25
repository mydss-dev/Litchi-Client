import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../theme/v3_motion.dart';
import 'v3_components.dart';
import 'v3_empty_state.dart';
import 'v3_node_picker.dart';
import 'v3_locale_copy.dart';
import 'v3_latency_tier.dart';
import 'v3_node_tags.dart';

/// Flutter translation of design/elegant_mockup.html phone nodes:
/// .page-head, .nsearch, .nchips, .nlist, .nrow, .nright.
/// Business operations remain in V3NodesPage.
class V3HtmlPhoneNodes extends StatelessWidget {
  const V3HtmlPhoneNodes({
    super.key,
    required this.controller,
    required this.nodes,
    required this.total,
    required this.regions,
    required this.search,
    required this.onQuery,
    required this.region,
    required this.onRegion,
    required this.onTest,
    required this.onTestNode,
    required this.onSelect,
    required this.onSelectAuto,
    required this.pendingId,
    required this.testingNodeId,
  });

  final AppController controller;
  final List<NodeModel> nodes;
  final int total;
  final int regions;
  final TextEditingController search;
  final ValueChanged<String> onQuery;
  final NodeRegion? region;
  final ValueChanged<NodeRegion?> onRegion;
  final VoidCallback onTest;
  final ValueChanged<String> onTestNode;
  final ValueChanged<NodeModel> onSelect;
  final VoidCallback onSelectAuto;
  final String? pendingId;
  final String? testingNodeId;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final filters = <(NodeRegion?, String)>[
      (null, v3Copy(context, zh: '全部', en: 'All', tw: '全部')),
      (NodeRegion.asia, v3Copy(context, zh: '亚洲', en: 'Asia', tw: '亞洲')),
      (NodeRegion.europe, v3Copy(context, zh: '欧洲', en: 'Europe', tw: '歐洲')),
      (NodeRegion.america, v3Copy(context, zh: '美洲', en: 'Americas', tw: '美洲')),
    ];
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        V3PrimaryPageHeader(
          title: v3Copy(context, zh: '节点', en: 'Nodes', tw: '節點'),
          subtitle: v3Copy(context,
            zh: '$total 个节点 · $regions 个地区',
            en: '$total nodes · $regions regions',
            tw: '$total 個節點 · $regions 個地區'),
          trailing: SizedBox(height: 36, child: OutlinedButton.icon(
            key: const Key('v3-overview-speed-test'),
            onPressed: controller.isLatencyTesting || testingNodeId != null
                ? null : onTest,
            icon: controller.isLatencyTesting
                ? SizedBox(width: 17, height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: p.lycheeInk))
                : const Icon(LucideIcons.zap, size: 17),
            label: Text(v3Copy(context, zh: '全部测速',
              en: 'Test all', tw: '全部測速')),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.line),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
          )),
        ),
        const SizedBox(height: 18),
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: p.surface,
            border: Border.all(color: p.hairline),
            borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: search,
            onChanged: onQuery,
            style: TextStyle(color: p.ink, fontSize: 12),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.only(top: 12),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted, size: 17),
              hintText: v3Copy(context, zh: '搜索节点',
                en: 'Search nodes', tw: '搜尋節點'),
              hintStyle: TextStyle(color: p.inkMuted,
                fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (index, filter) in filters.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              V3MobileFilterChip(
                key: ValueKey(filter.$1 == null
                    ? 'v3-map-country-all' : 'v3-region-${filter.$1}'),
                selected: region == filter.$1, label: filter.$2,
                onTap: () => onRegion(filter.$1)),
            ],
          ]),
        ),
        const SizedBox(height: 15),
        Material(
          color: controller.autoSelected ? p.lycheeSoft : p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: controller.autoSelected
                ? p.lychee.withValues(alpha: .65)
                : p.line.withValues(alpha: .72))),
          child: InkWell(
            key: const ValueKey('v3-mobile-auto-node'),
            borderRadius: BorderRadius.circular(18),
            onTap: controller.autoSelected || pendingId != null
                ? null : onSelectAuto,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 12),
              child: Row(children: [
                Container(
                  height: 36, width: 36,
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.auto_awesome_rounded,
                    color: p.lycheeInk, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v3Copy(context, zh: '自动选择节点',
                        en: 'Automatic selection', tw: '自動選擇節點'),
                      style: TextStyle(color: p.ink,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(v3Copy(context, zh: '由系统选择合适线路',
                        en: 'Let the app select a route',
                        tw: '由系統選擇合適線路'),
                      style: TextStyle(color: p.inkMuted, fontSize: 11)),
                  ],
                )),
                if (controller.autoSelected)
                  Icon(Icons.check_circle_rounded,
                    color: p.lycheeInk, size: 19)
                else
                  Icon(Icons.chevron_right_rounded,
                    color: p.inkMuted, size: 19),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 13),
        if (controller.isInitialLoading)
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 9),
              child: V3NodeSkeletonRow())
        else if (controller.dataLoadError != null && total == 0)
          V3EmptyState(
            icon: Icons.error_outline_rounded,
            title: v3Copy(context, zh: '节点同步失败',
              en: 'Could not load nodes', tw: '節點同步失敗'),
            subtitle: controller.dataLoadError!,
            actionLabel: v3Copy(context, zh: '重试',
              en: 'Retry', tw: '重試'),
            onAction: controller.refreshData,
          )
        else if (nodes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(v3Copy(context, zh: '没有匹配的节点',
              en: 'No matching nodes', tw: '沒有符合的節點'),
              style: TextStyle(color: p.inkMuted)),
          )
        else
          for (final node in nodes)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _HtmlNodeRow(
                node: node,
                selected: !controller.autoSelected &&
                  controller.currentNode.id == node.id,
                blocked: pendingId != null,
                pending: pendingId == node.id,
                testing: testingNodeId == node.id ||
                  (controller.isLatencyTesting && testingNodeId == null),
                canTest: pendingId == null &&
                  !controller.isLatencyTesting && testingNodeId == null,
                onTap: () => onSelect(node),
                onTest: () => onTestNode(node.id),
              ),
            ),
      ]),
    );
  }
}

class _HtmlNodeRow extends StatelessWidget {
  const _HtmlNodeRow({
    required this.node, required this.selected,
    required this.blocked, required this.pending,
    required this.testing, required this.canTest, required this.onTap,
    required this.onTest,
  });

  final NodeModel node;
  final bool selected;
  final bool blocked;
  final bool pending;
  final bool testing;
  final bool canTest;
  final VoidCallback onTap;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: selected ? p.lycheeSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected
            ? p.lychee.withValues(alpha: .60)
            : p.line.withValues(alpha: .72))),
      child: InkWell(
        key: ValueKey('v3-html-node-${node.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: blocked || selected ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 73),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(children: [
              Container(
                height: 34, width: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.surfaceRaised,
                  border: Border.all(color: p.hairline),
                  borderRadius: BorderRadius.circular(12)),
                child: V3NodeFlag(code: node.code),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: selected ? p.lycheeInk : p.ink,
                      fontSize: 14, fontWeight: FontWeight.w700)),
                  if (node.englishName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(node.englishName, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.inkMuted, fontSize: 11)),
                  ],
                  if (selected || node.tags.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(children: [
                      if (selected) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: p.lycheeSoft,
                            borderRadius: BorderRadius.circular(99)),
                          child: Text(v3Copy(context, zh: '当前',
                            en: 'Current', tw: '目前'),
                            style: TextStyle(color: p.lycheeInk, fontSize: 10)),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(child: V3NodeTags(
                        tags: node.tags, maxVisible: 2,
                        chipMaxWidth: 50, showOverflow: false)),
                    ]),
                  ],
                ],
              )),
              const SizedBox(width: 5),
              // Untested: outline bolt. Testing: live spinner. Result:
              // shared region-aware latency capsule (green/amber/red).
              // Retesting the capsule stays possible via the same hit area.
              SizedBox(
                width: 74, height: 44,
                child: TextButton(
                  key: ValueKey('v3-node-latency-${node.id}'),
                  onPressed: canTest ? onTest : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: p.inkMuted,
                    minimumSize: const Size(48, 44)),
                  child: AnimatedSwitcher(
                    duration: V3Motion.fast,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: testing
                      ? SizedBox(
                          key: const ValueKey('v3-node-speed-loading'),
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.lycheeInk))
                      : node.latency <= 0
                        ? Icon(LucideIcons.zap,
                            key: const ValueKey('v3-node-speed-untested'),
                            size: 21, color: p.inkMuted)
                        : V3LatencyBadge(
                            key: ValueKey('v3-node-speed-result-${node.id}'),
                            region: node.region, latency: node.latency),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

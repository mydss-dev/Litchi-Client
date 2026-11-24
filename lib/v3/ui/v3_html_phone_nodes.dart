import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import 'v3_components.dart';
import 'v3_latency_tier.dart';
import 'v3_locale_copy.dart';
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
    required this.isFavorite,
    required this.onFavorite,
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
  final bool Function(NodeModel) isFavorite;
  final ValueChanged<NodeModel> onFavorite;

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
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v3Copy(context, zh: '节点', en: 'Nodes', tw: '節點'),
                style: TextStyle(color: p.ink, fontSize: 28,
                  fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('$total 个可用节点 · $regions 个地区',
                style: TextStyle(color: p.inkMuted, fontSize: 13)),
            ],
          )),
          SizedBox(height: 36, child: OutlinedButton.icon(
            key: const Key('v3-overview-speed-test'),
            onPressed: controller.isLatencyTesting ? null : onTest,
            icon: const Icon(Icons.arrow_upward_rounded, size: 15),
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
        ]),
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
              suffixIcon: Icon(Icons.tune_rounded, color: p.inkMuted, size: 17),
              hintText: v3Copy(context, zh: '搜索节点',
                en: 'Search nodes', tw: '搜尋節點'),
              hintStyle: TextStyle(color: p.inkMuted,
                fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (code, label) in filters)
            _RegionChip(
              key: ValueKey(code == null ? 'v3-map-country-all' : 'v3-region-$code'),
              selected: region == code, title: label,
              onTap: () => onRegion(code)),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.hairline)),
          child: Column(children: [
            if (controller.isInitialLoading)
              Padding(padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: p.lychee))
            else if (controller.dataLoadError != null && total == 0)
              Padding(padding: const EdgeInsets.all(20),
                child: Text(controller.dataLoadError!,
                  style: TextStyle(color: p.inkMuted)))
            else if (nodes.isEmpty)
              Padding(padding: const EdgeInsets.all(20),
                child: Text(v3Copy(context, zh: '没有匹配的节点',
                  en: 'No matching nodes', tw: '沒有符合的節點'),
                  style: TextStyle(color: p.inkMuted)))
            else
              for (final node in nodes)
                _HtmlNodeRow(
                  node: node,
                  selected: !controller.autoSelected &&
                    controller.currentNode.id == node.id,
                  favorite: isFavorite(node),
                  blocked: pendingId != null,
                  pending: pendingId == node.id,
                  onTap: () => onSelect(node),
                  onFavorite: () => onFavorite(node),
                  onTest: () => onTestNode(node.id)),
          ]),
        ),
        const SizedBox(height: 10),
        if (!controller.autoSelected)
          TextButton.icon(
            onPressed: onSelectAuto,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: Text(v3Copy(context, zh: '自动选择节点',
              en: 'Automatic selection', tw: '自動選擇節點')),
          ),
      ]),
    );
  }
}

class _RegionChip extends StatelessWidget {
  const _RegionChip({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
  });
  final bool selected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: selected ? p.lycheeSoft : p.surfaceRaised,
      shape: StadiumBorder(side: BorderSide(
        color: selected ? p.lychee : p.hairline)),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(title, style: TextStyle(
            color: selected ? p.lycheeInk : p.inkMuted,
            fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _HtmlNodeRow extends StatelessWidget {
  const _HtmlNodeRow({
    required this.node, required this.selected, required this.favorite,
    required this.blocked, required this.pending, required this.onTap,
    required this.onFavorite, required this.onTest,
  });

  final NodeModel node;
  final bool selected;
  final bool favorite;
  final bool blocked;
  final bool pending;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Material(
      color: selected ? p.lycheeSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('v3-html-node-${node.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: blocked || selected ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
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
                      fontSize: 13, fontWeight: FontWeight.w700)),
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
                          decoration: BoxDecoration(color: p.lychee,
                            borderRadius: BorderRadius.circular(99)),
                          child: Text(v3Copy(context, zh: '当前',
                            en: 'Current', tw: '目前'),
                            style: TextStyle(color: p.onLychee, fontSize: 10)),
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
              V3LatencyBadge(region: node.region, latency: node.latency),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏节点',
                onPressed: onFavorite,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 18, color: favorite ? p.lycheeInk : p.inkMuted),
              ),
              SizedBox(width: 34, height: 34,
                child: OutlinedButton(
                  onPressed: blocked ? null : onTest,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: p.surfaceRaised,
                    shape: const CircleBorder(),
                    side: BorderSide(color: p.hairline),
                    padding: EdgeInsets.zero),
                  child: pending
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(Icons.arrow_upward_rounded,
                        size: 16, color: p.inkMuted),
                )),
            ]),
          ),
        ),
      ),
    );
  }
}

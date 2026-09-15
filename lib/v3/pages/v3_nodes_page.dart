import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';

class V3NodesPage extends StatefulWidget {
  const V3NodesPage({super.key});

  @override
  State<V3NodesPage> createState() => _V3NodesPageState();
}

class _V3NodesPageState extends State<V3NodesPage> {
  String _query = '';
  NodeRegion? _region;
  bool _testing = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final nodes = controller.nodes.where((node) {
      final query = _query.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          node.name.toLowerCase().contains(query) ||
          node.englishName.toLowerCase().contains(query) ||
          node.code.toLowerCase().contains(query);
      final matchesRegion = _region == null || node.region == _region;
      return matchesQuery && matchesRegion;
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final columns = compact ? 1 : constraints.maxWidth >= 1040 ? 3 : 2;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(compact ? 20 : 34, 26, compact ? 20 : 34, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ROUTE LIBRARY', style: TextStyle(color: p.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                              const SizedBox(height: 7),
                              Text('节点矩阵', style: Theme.of(context).textTheme.displayLarge),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: _testing || controller.nodes.isEmpty
                                ? null
                                : () async {
                                    setState(() => _testing = true);
                                    try {
                                      await controller.testLatencies();
                                    } finally {
                                      if (mounted) setState(() => _testing = false);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.text,
                              side: BorderSide(color: p.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _testing
                                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.radar_rounded, size: 17),
                            label: Text(_testing ? '测速中' : '全部测速'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _SearchBox(onChanged: (value) => setState(() => _query = value)),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(label: '全部', selected: _region == null, onTap: () => setState(() => _region = null)),
                          const SizedBox(width: 8),
                          ...NodeRegion.values.expand((region) => [
                                _FilterChip(label: _regionLabel(region), selected: _region == region, onTap: () => setState(() => _region = region)),
                                const SizedBox(width: 8),
                              ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _AutoRouteTile(controller: controller),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (nodes.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(controller.nodes.isEmpty ? '还没有可用节点' : '没有匹配结果', style: TextStyle(color: p.textMuted)),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(compact ? 20 : 34, 0, compact ? 20 : 34, 34),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 142,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _NodeTile(node: nodes[index], controller: controller),
                    childCount: nodes.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AutoRouteTile extends StatelessWidget {
  const _AutoRouteTile({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected = controller.autoSelected;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        final error = await controller.selectAuto();
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        decoration: BoxDecoration(
          color: selected ? p.rail : p.panelStrong,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: selected ? p.accent : p.panel, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.auto_awesome_rounded, color: selected ? Colors.white : p.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Litchi Auto Route', style: TextStyle(color: selected ? Colors.white : p.text, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('根据可用性与延迟自动保持最佳路线', style: TextStyle(color: selected ? Colors.white.withValues(alpha: 0.5) : p.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, required this.controller});
  final NodeModel node;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected = !controller.autoSelected && controller.currentNode.id == node.id;
    final latencyColor = node.latency > 0 && node.latency <= 120
        ? p.success
        : node.latency > 120 && node.latency < 9999
            ? p.warning
            : p.textMuted;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () async {
        final error = await controller.setCurrentNode(node);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? p.accentSoft : p.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? p.accent.withValues(alpha: 0.5) : p.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(node.flag.isEmpty ? '◎' : node.flag, style: const TextStyle(fontSize: 23)),
                const Spacer(),
                Container(width: 7, height: 7, decoration: BoxDecoration(color: latencyColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_latency(node.latency), style: TextStyle(color: latencyColor, fontSize: 10, fontWeight: FontWeight.w800)),
              ],
            ),
            const Spacer(),
            Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 4),
            Text(node.englishName.isNotEmpty ? node.englishName : node.code, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 48,
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.border)),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search_rounded, color: p.textMuted, size: 19),
          hintText: '搜索地区 / 节点 / 国家代码',
          hintStyle: TextStyle(color: p.textMuted, fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: selected ? p.rail : p.panel, borderRadius: BorderRadius.circular(13), border: Border.all(color: selected ? p.rail : p.border)),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : p.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

String _regionLabel(NodeRegion region) => switch (region) {
      NodeRegion.asia => '亚洲',
      NodeRegion.europe => '欧洲',
      NodeRegion.america => '美洲',
      NodeRegion.oceania => '大洋洲',
    };

String _latency(int value) {
  if (value == -1) return 'TEST';
  if (value <= 0) return '--';
  if (value >= 9999) return 'TIMEOUT';
  return '${value}ms';
}

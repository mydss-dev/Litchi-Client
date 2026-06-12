import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileNodesPage extends StatefulWidget {
  const MobileNodesPage({super.key});

  @override
  State<MobileNodesPage> createState() => _MobileNodesPageState();
}

class _MobileNodesPageState extends State<MobileNodesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = ctrl.nodes.where((node) {
      final key = _query.trim().toLowerCase();
      if (key.isEmpty) return true;
      return node.name.toLowerCase().contains(key) || node.englishName.toLowerCase().contains(key) || node.code.toLowerCase().contains(key);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('节点', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
                  const SizedBox(height: 3),
                  Text('选择适合你的线路', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            IconButton(onPressed: ctrl.refreshNodes, icon: Icon(LucideIcons.refreshCw, color: c.primary)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索节点'),
        ),
        const SizedBox(height: 12),
        _AutoSelectCard(selected: ctrl.autoSelected, onTap: ctrl.selectAuto),
        const SizedBox(height: 12),
        Expanded(
          child: nodes.isEmpty
              ? Center(child: Text('暂无节点', style: AppTextStyles.body.copyWith(color: c.textMuted)))
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: nodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    return _NodeTile(
                      node: node,
                      selected: !ctrl.autoSelected && ctrl.currentNode.id == node.id,
                      onTap: () => ctrl.setCurrentNode(node),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AutoSelectCard extends StatelessWidget {
  const _AutoSelectCard({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: selected ? c.primary : c.softBorder),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.zap, color: c.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('自动选择', style: AppTextStyles.bodyStrong)),
            if (selected) Icon(LucideIcons.circleCheck, color: c.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({required this.node, required this.selected, required this.onTap});

  final NodeModel node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: selected ? c.primary : c.softBorder),
        ),
        child: Row(
          children: [
            _NodeFlag(node: node),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(node.englishName.isEmpty ? node.region.name : node.englishName, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            _Latency(latency: node.latency),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(LucideIcons.circleCheck, color: c.primary, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _NodeFlag extends StatelessWidget {
  const _NodeFlag({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final flag = node.flag.isNotEmpty ? node.flag : '🌐';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(AppRadius.sm)),
      child: Text(flag, style: const TextStyle(fontSize: 20)),
    );
  }
}

class _Latency extends StatelessWidget {
  const _Latency({required this.latency});

  final int latency;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (latency == -1) {
      return SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.warning));
    }
    if (latency <= 0 || latency >= 9999) {
      return Text('--', style: AppTextStyles.caption.copyWith(color: c.textMuted));
    }
    final color = latency < 150 ? c.success : c.danger;
    return Text('$latency ms', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700));
  }
}

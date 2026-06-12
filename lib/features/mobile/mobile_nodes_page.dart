import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileNodesPage extends StatelessWidget {
  const MobileNodesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = ctrl.nodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('节点', style: AppTextStyles.h1.copyWith(fontSize: 26)),
        const SizedBox(height: 3),
        Text('选择适合你的线路', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: 14),
        _AutoSelectCard(selected: ctrl.autoSelected, onTap: ctrl.selectAuto),
        const SizedBox(height: 12),
        Expanded(
          child: nodes.isEmpty
              ? Center(
                  child: Text(
                    '暂无节点，请检查服务器连接',
                    style: AppTextStyles.body.copyWith(color: c.textMuted),
                  ),
                )
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
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(LucideIcons.zap, color: c.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('自动选择', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text('根据测速结果自动选择最优节点', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
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
    final code = node.code.isNotEmpty ? node.code : 'UN';

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
            CountryFlag.fromCountryCode(
              code,
              theme: const ImageTheme(
                width: 32,
                height: 24,
                shape: RoundedRectangle(4),
              ),
            ),
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
            const SizedBox(width: 8),
            if (selected) Icon(LucideIcons.circleCheck, color: c.primary, size: 18),
          ],
        ),
      ),
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
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.warning),
      );
    }
    if (latency <= 0 || latency >= 9999) {
      return Text('--', style: AppTextStyles.caption.copyWith(color: c.textMuted));
    }
    final color = latency < 150 ? c.success : c.danger;
    return Text('$latency ms', style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700));
  }
}

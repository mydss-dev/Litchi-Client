import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileHomePage extends StatelessWidget {
  const MobileHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final current = ctrl.currentNode;

    return RefreshIndicator(
      onRefresh: ctrl.refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Litchi', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
                    const SizedBox(height: 3),
                    Text('移动端业务面板', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              IconButton(onPressed: ctrl.refreshData, icon: Icon(LucideIcons.refreshCw, color: c.primary)),
            ],
          ),
          const SizedBox(height: 14),
          if (ctrl.dataLoadError != null) ...[
            _InfoCard(icon: LucideIcons.triangleAlert, title: '缓存模式', subtitle: ctrl.dataLoadError!, color: c.warning),
            const SizedBox(height: 12),
          ],
          _ConnectCard(nodeName: current.name.isEmpty ? '请选择节点' : current.name),
          const SizedBox(height: 12),
          _HomeNodePicker(),
          const SizedBox(height: 12),
          _InfoCard(icon: LucideIcons.crown, title: '当前套餐', subtitle: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan, color: c.primary),
          const SizedBox(height: 12),
          _InfoCard(icon: LucideIcons.activity, title: '流量剩余', subtitle: '${ctrl.traffic.remainGb.toStringAsFixed(1)} GB', color: c.success),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.nodeName});

  final String nodeName;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.softBorder)),
      child: Column(
        children: [
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.surfaceMuted, border: Border.all(color: c.softBorder, width: 8)),
            child: Icon(LucideIcons.power, size: 44, color: c.textMuted),
          ),
          const SizedBox(height: 16),
          Text('点击连接', style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(nodeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text('Android VPN 核心稍后接入', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _HomeNodePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final current = ctrl.currentNode;
    final nodes = ctrl.nodes.take(8).toList();

    return Container(
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(LucideIcons.globe, color: c.secondary, size: 20),
        title: Text('选择节点', style: AppTextStyles.bodyStrong),
        subtitle: Text(ctrl.autoSelected ? '自动选择' : (current.name.isEmpty ? '未选择' : current.name), style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        children: [
          _NodeChoiceTile(
            title: '自动选择',
            subtitle: '根据测速结果选择最优节点',
            selected: ctrl.autoSelected,
            onTap: ctrl.selectAuto,
          ),
          for (final node in nodes)
            _NodeChoiceTile(
              title: node.name,
              subtitle: node.englishName.isEmpty ? node.region.name : node.englishName,
              selected: !ctrl.autoSelected && current.id == node.id,
              onTap: () => ctrl.setCurrentNode(node),
            ),
          if (ctrl.nodes.length > nodes.length)
            ListTile(
              dense: true,
              title: Text('更多节点', style: AppTextStyles.bodyStrong),
              subtitle: Text('进入节点页查看全部 ${ctrl.nodes.length} 个节点', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              trailing: Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
              onTap: () => ctrl.goToPage(AppPage.nodes),
            ),
        ],
      ),
    );
  }
}

class _NodeChoiceTile extends StatelessWidget {
  const _NodeChoiceTile({required this.title, required this.subtitle, required this.selected, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
      trailing: selected ? Icon(LucideIcons.circleCheck, color: c.primary, size: 18) : null,
      onTap: onTap,
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle, required this.color});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

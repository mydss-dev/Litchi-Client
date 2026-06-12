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
          _InfoCard(icon: LucideIcons.crown, title: '当前套餐', subtitle: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan, color: c.primary),
          const SizedBox(height: 12),
          _InfoCard(icon: LucideIcons.globe, title: '当前节点', subtitle: current.name.isEmpty ? '未选择' : current.name, color: c.secondary),
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

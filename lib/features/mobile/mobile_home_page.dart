import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
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
    final nodes = ctrl.nodes.take(6).toList();

    return RefreshIndicator(
      onRefresh: ctrl.refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(child: Text('Litchi', style: AppTextStyles.pageTitle.copyWith(fontSize: 26))),
              IconButton(onPressed: ctrl.refreshData, icon: Icon(LucideIcons.refreshCw, color: c.primary)),
            ],
          ),
          const SizedBox(height: 14),
          _ConnectCard(nodeName: current.name.isEmpty ? '请选择节点' : current.name),
          const SizedBox(height: 12),
          _ModeCard(),
          const SizedBox(height: 12),
          _NodePicker(nodes: nodes),
          const SizedBox(height: 12),
          _InfoCard(icon: LucideIcons.crown, title: '当前套餐', subtitle: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan, color: c.primary),
          const SizedBox(height: 12),
          _InfoCard(icon: LucideIcons.activity, title: '流量剩余', subtitle: '${ctrl.traffic.remainGb.toStringAsFixed(1)} GB', color: c.success),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    return Row(
      children: [
        Expanded(child: _ModeButton(text: '规则', mode: ProxyMode.rule, selected: ctrl.proxyMode == ProxyMode.rule)),
        const SizedBox(width: 8),
        Expanded(child: _ModeButton(text: '全局', mode: ProxyMode.global, selected: ctrl.proxyMode == ProxyMode.global)),
        const SizedBox(width: 8),
        Expanded(child: _ModeButton(text: '直连', mode: ProxyMode.direct, selected: ctrl.proxyMode == ProxyMode.direct)),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.text, required this.mode, required this.selected});

  final String text;
  final ProxyMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => ctrl.setProxyMode(mode),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.primarySoft : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? c.primary : c.softBorder),
        ),
        child: Text(text, style: AppTextStyles.bodyStrong.copyWith(color: selected ? c.primary : c.textMuted)),
      ),
    );
  }
}

class _NodePicker extends StatelessWidget {
  const _NodePicker({required this.nodes});

  final List<NodeModel> nodes;

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final current = ctrl.currentNode;
    return Container(
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: ExpansionTile(
        leading: Icon(LucideIcons.globe, color: c.secondary),
        title: Text('选择节点', style: AppTextStyles.bodyStrong),
        subtitle: Text(ctrl.autoSelected ? '自动选择' : current.name, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        children: [
          ListTile(title: const Text('自动选择'), onTap: ctrl.selectAuto),
          for (final node in nodes)
            ListTile(
              title: Text(node.name),
              trailing: !ctrl.autoSelected && current.id == node.id ? Icon(LucideIcons.circleCheck, color: c.primary) : null,
              onTap: () => ctrl.setCurrentNode(node),
            ),
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
          Icon(LucideIcons.power, size: 64, color: c.textMuted),
          const SizedBox(height: 12),
          Text('点击连接', style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(nodeName, style: AppTextStyles.body.copyWith(color: c.textMuted)),
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
          Expanded(child: Text('$title\n$subtitle', style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

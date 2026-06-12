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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Litchi Client', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
                    const SizedBox(height: 4),
                    Text('移动端控制台', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              _IconBox(icon: LucideIcons.refreshCw, onTap: ctrl.refreshData),
            ],
          ),
          const SizedBox(height: 16),
          _HeroConnectCard(nodeName: current.name.isEmpty ? '请选择节点' : current.name),
          const SizedBox(height: 12),
          _ModeCard(),
          const SizedBox(height: 12),
          _NodePicker(nodes: nodes),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniInfo(title: '套餐', value: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan, icon: LucideIcons.crown, color: c.primary)),
              const SizedBox(width: 10),
              Expanded(child: _MiniInfo(title: '剩余流量', value: '${ctrl.traffic.remainGb.toStringAsFixed(1)} GB', icon: LucideIcons.activity, color: c.success)),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: c.softBorder)),
        child: Icon(icon, color: c.primary, size: 19),
      ),
    );
  }
}

class _HeroConnectCard extends StatelessWidget {
  const _HeroConnectCard({required this.nodeName});
  final String nodeName;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: c.brandGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.18), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(
        children: [
          Container(
            width: 118,
            height: 118,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15), border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 8)),
            child: const Icon(LucideIcons.power, size: 42, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text('点击连接', style: AppTextStyles.pageTitle.copyWith(color: Colors.white, fontSize: 24)),
          const SizedBox(height: 5),
          Text(nodeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.82))),
          const SizedBox(height: 6),
          Text('Android VPN 核心稍后接入', style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.68))),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Expanded(child: _ModeButton(text: '规则', mode: ProxyMode.rule)),
          Expanded(child: _ModeButton(text: '全局', mode: ProxyMode.global)),
          Expanded(child: _ModeButton(text: '直连', mode: ProxyMode.direct)),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.text, required this.mode});
  final String text;
  final ProxyMode mode;

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final selected = ctrl.proxyMode == mode;
    return GestureDetector(
      onTap: () => ctrl.setProxyMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? c.primarySoft : Colors.transparent, borderRadius: BorderRadius.circular(AppRadius.md)),
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
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(LucideIcons.globe, color: c.secondary),
        title: Text('选择节点', style: AppTextStyles.bodyStrong),
        subtitle: Text(ctrl.autoSelected ? '自动选择' : current.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        children: [
          _NodeRow(flag: '⚡', title: '自动选择', selected: ctrl.autoSelected, onTap: ctrl.selectAuto),
          for (final node in nodes)
            _NodeRow(
              flag: node.flag.isEmpty ? '🌐' : node.flag,
              title: node.name,
              selected: !ctrl.autoSelected && current.id == node.id,
              onTap: () => ctrl.setCurrentNode(node),
            ),
        ],
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.flag, required this.title, required this.selected, required this.onTap});
  final String flag;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
      trailing: selected ? Icon(LucideIcons.circleCheck, color: c.primary, size: 18) : null,
      onTap: onTap,
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        Text(title, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
      ]),
    );
  }
}

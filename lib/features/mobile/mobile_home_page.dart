import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
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
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;
    final usedPercent = ctrl.traffic.usedPercent.clamp(0, 100).toDouble();

    return RefreshIndicator(
      onRefresh: ctrl.refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _MobileHeader(onRefresh: ctrl.refreshData),
          const SizedBox(height: 14),
          if (ctrl.dataLoadError != null) ...[
            _WarningCard(message: ctrl.dataLoadError!),
            const SizedBox(height: 14),
          ],
          _ConnectCard(
            connected: connected,
            loading: false,
            nodeName: current.name.isEmpty ? '请选择节点' : current.name,
            onTap: () => _showPending(context),
          ),
          const SizedBox(height: 14),
          _TrafficCard(
            usedGb: ctrl.traffic.usedGb,
            remainGb: ctrl.traffic.remainGb,
            totalGb: ctrl.traffic.totalGb,
            usedPercent: usedPercent,
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '当前套餐',
            value: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan,
            subtitle: ctrl.user.expiry.isEmpty ? '暂无到期时间' : '到期：${ctrl.user.expiry}',
            icon: LucideIcons.crown,
            color: c.primary,
            onTap: () => ctrl.goToPage(AppPage.shop),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            title: '当前节点',
            value: current.name.isEmpty ? '未选择' : current.name,
            subtitle: ctrl.autoSelected ? '自动选择 · ${ctrl.nodes.length} 个节点' : '手动选择 · ${ctrl.nodes.length} 个节点',
            icon: LucideIcons.globe,
            color: c.secondary,
            onTap: () => ctrl.goToPage(AppPage.nodes),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStatCard(label: '在线 IP', value: ctrl.aliveIp?.toString() ?? '--')),
              const SizedBox(width: 10),
              Expanded(child: _MiniStatCard(label: '设备限制', value: ctrl.deviceLimit?.toString() ?? '--')),
            ],
          ),
        ],
      ),
    );
  }

  void _showPending(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('移动端连接能力稍后接入，当前先完成 UI 与 API。')),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Litchi', style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 3),
              Text('移动端业务面板', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => onRefresh(),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(LucideIcons.refreshCw, color: c.primary, size: 18),
          ),
        ),
      ],
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.triangleAlert, color: c.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(color: c.warning))),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({required this.connected, required this.loading, required this.nodeName, required this.onTap});
  final bool connected;
  final bool loading;
  final String nodeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.softBorder)),
      child: Column(
        children: [
          GestureDetector(
            onTap: loading ? null : onTap,
            child: Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? c.primary.withValues(alpha: 0.12) : c.surfaceMuted,
                border: Border.all(color: connected ? c.primary.withValues(alpha: 0.40) : c.softBorder, width: 8),
              ),
              child: loading ? CircularProgressIndicator(color: c.primary) : Icon(LucideIcons.power, size: 44, color: connected ? c.primary : c.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          Text(connected ? '已连接' : '点击连接', style: AppTextStyles.h2.copyWith(color: connected ? c.primary : c.textPrimary)),
          const SizedBox(height: 6),
          Text(nodeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.body.copyWith(color: c.textMuted)),
        ],
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.usedGb, required this.remainGb, required this.totalGb, required this.usedPercent});
  final double usedGb;
  final double remainGb;
  final double totalGb;
  final double usedPercent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ratio = (usedPercent / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Text('流量使用', style: AppTextStyles.bodyStrong), const Spacer(), Text('${usedPercent.toStringAsFixed(0)}%', style: AppTextStyles.caption.copyWith(color: c.textMuted))]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: ratio, minHeight: 9, backgroundColor: c.surfaceMuted, color: c.primary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('已用 ${usedGb.toStringAsFixed(1)} GB', style: AppTextStyles.caption.copyWith(color: c.textMuted))),
              Text('剩余 ${remainGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, this.onTap});
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                  const SizedBox(height: 3),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                ],
              ),
            ),
            if (onTap != null) Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

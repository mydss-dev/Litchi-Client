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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _MobileHeader(
          title: 'Litchi',
          subtitle: connected ? '已连接' : '未连接',
        ),
        const SizedBox(height: 14),
        if (ctrl.dataLoadError != null) ...[
          _WarningCard(message: ctrl.dataLoadError!),
          const SizedBox(height: 14),
        ],
        _ConnectCard(
          connected: connected,
          loading: ctrl.coreConnecting,
          nodeName: current.name.isEmpty ? '请选择节点' : current.name,
          onTap: () => ctrl.toggleConnection(),
        ),
        const SizedBox(height: 14),
        _InfoCard(
          title: '当前套餐',
          value: ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan,
          subtitle: '剩余 ${ctrl.traffic.remainGb.toStringAsFixed(1)} GB / ${ctrl.traffic.totalGb.toStringAsFixed(1)} GB',
          icon: LucideIcons.crown,
          color: c.primary,
        ),
        const SizedBox(height: 12),
        _InfoCard(
          title: '当前节点',
          value: current.name.isEmpty ? '未选择' : current.name,
          subtitle: ctrl.autoSelected ? '自动选择' : '手动选择',
          icon: LucideIcons.globe2,
          color: c.secondary,
        ),
      ],
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(LucideIcons.zap, color: c.primary, size: 19),
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
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: c.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.connected,
    required this.loading,
    required this.nodeName,
    required this.onTap,
  });

  final bool connected;
  final bool loading;
  final String nodeName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.softBorder),
      ),
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
                border: Border.all(
                  color: connected ? c.primary.withValues(alpha: 0.40) : c.softBorder,
                  width: 8,
                ),
              ),
              child: loading
                  ? CircularProgressIndicator(color: c.primary)
                  : Icon(
                      LucideIcons.power,
                      size: 44,
                      color: connected ? c.primary : c.textMuted,
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            connected ? '已连接' : '点击连接',
            style: AppTextStyles.h2.copyWith(color: connected ? c.primary : c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            nodeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

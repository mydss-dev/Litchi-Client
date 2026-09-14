import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../app/nav_destinations.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/traffic_summary_text.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';

class GreenfieldRealtimeSurface extends StatelessWidget {
  const GreenfieldRealtimeSurface({
    super.key,
    required this.ctrl,
    required this.tick,
    required this.compact,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    final download = ValueListenableBuilder<int>(
      valueListenable: ctrl.downBpsNotifier,
      builder: (context, value, _) => _MetricCell(
        icon: LucideIcons.arrowDown,
        label: context.l10n.downloadSpeed,
        value: formatRate(value),
        active: connected,
      ),
    );
    final upload = ValueListenableBuilder<int>(
      valueListenable: ctrl.upBpsNotifier,
      builder: (context, value, _) => _MetricCell(
        icon: LucideIcons.arrowUp,
        label: context.l10n.uploadSpeed,
        value: formatRate(value),
        active: connected,
      ),
    );
    final duration = ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, _) => _MetricCell(
        icon: LucideIcons.clock3,
        label: context.l10n.connectionDurationLabel,
        value: formatDuration(ctrl.connectedDuration),
        active: connected,
      ),
    );

    return AppCard(
      height: compact ? null : 100,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: compact
          ? Column(
              children: [
                Row(
                  children: [
                    Expanded(child: download),
                    _VerticalRule(color: c.softBorder, height: 44),
                    Expanded(child: upload),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(height: 1, thickness: 1, color: c.softBorder),
                const SizedBox(height: AppSpacing.md),
                duration,
              ],
            )
          : Row(
              children: [
                Expanded(child: download),
                _VerticalRule(color: c.softBorder, height: 46),
                Expanded(child: upload),
                _VerticalRule(color: c.softBorder, height: 46),
                Expanded(child: duration),
              ],
            ),
    );
  }
}

class GreenfieldSubscriptionSurface extends StatelessWidget {
  const GreenfieldSubscriptionSurface({
    super.key,
    required this.ctrl,
    required this.compact,
  });

  final AppController ctrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final expiry = subscriptionExpiryDisplay(
      expiredAt: ctrl.expiredAt,
      expiryText: ctrl.user.expiry,
    );
    final total = ctrl.traffic.totalGb;
    final remaining = ctrl.traffic.remainGb;
    final used = total > 0
        ? (total - remaining).clamp(0.0, total).toDouble()
        : 0.0;
    final progress = total > 0
        ? (used / total).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final planName = ctrl.user.plan.trim().isEmpty
        ? 'Litchi'
        : ctrl.user.plan.trim();

    final remainingMetric = _PlanMetric(
      label: context.l10n.remainingTrafficLabel,
      value: formatGb(remaining),
    );
    final todayMetric = _PlanMetric(
      label: context.l10n.todayUsedLabel,
      value: formatGb(ctrl.todayTrafficGb),
    );
    final expiryMetric = _PlanMetric(
      label: context.l10n.expiryTime,
      value: expiry.date.isEmpty ? context.l10n.permanent : expiry.date,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(LucideIcons.crown, size: 17, color: c.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  planName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                total > 0 ? '${formatGb(used)} / ${formatGb(total)}' : '--',
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _TrafficProgress(value: progress),
          const SizedBox(height: AppSpacing.lg),
          if (compact) ...[
            Row(
              children: [
                Expanded(child: remainingMetric),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: todayMetric),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            expiryMetric,
          ] else
            Row(
              children: [
                Expanded(child: remainingMetric),
                _VerticalRule(color: c.softBorder, height: 38),
                Expanded(child: todayMetric),
                _VerticalRule(color: c.softBorder, height: 38),
                Expanded(child: expiryMetric),
              ],
            ),
        ],
      ),
    );
  }
}

class GreenfieldNoPlanSurface extends StatelessWidget {
  const GreenfieldNoPlanSurface({
    super.key,
    required this.ctrl,
    required this.compact,
  });

  final AppController ctrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canPurchase = isPageEnabled(AppPage.shop);
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.noCurrentPlan,
          style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.noPlanDescription,
          style: AppTextStyles.body.copyWith(
            color: c.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );

    final icon = Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Icon(LucideIcons.packageOpen, size: 25, color: c.primary),
    );

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.xl : 32),
      child: compact
          ? Column(
              children: [
                icon,
                const SizedBox(height: AppSpacing.lg),
                copy,
                if (canPurchase) ...[
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: context.l10n.buyPlans,
                    onPressed: () => ctrl.goToPage(AppPage.shop),
                    leadingIcon: LucideIcons.shoppingBag,
                    expand: true,
                  ),
                ],
              ],
            )
          : Row(
              children: [
                icon,
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: copy),
                if (canPurchase) ...[
                  const SizedBox(width: AppSpacing.xl),
                  AppButton(
                    label: context.l10n.buyPlans,
                    onPressed: () => ctrl.goToPage(AppPage.shop),
                    leadingIcon: LucideIcons.shoppingBag,
                  ),
                ],
              ],
            ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Opacity(
      opacity: active ? 1 : 0.56,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metricLabel.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metricValue.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.planValue.copyWith(color: c.textPrimary),
        ),
      ],
    );
  }
}

class _TrafficProgress extends StatelessWidget {
  const _TrafficProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.surfaceMuted),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: c.brandGradient),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalRule extends StatelessWidget {
  const _VerticalRule({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: color,
    );
  }
}

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../app/nav_destinations.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_breakpoints.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/traffic_summary_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/mode_strip.dart';
import '../../../shared/widgets/no_plan_card.dart';
import '../../../shared/widgets/node_latency.dart';
import '../../../shared/widgets/notice_bar.dart';
import 'litchi_connection_orb.dart';
import 'network_settings_card.dart';

/// Desktop dashboard visual hierarchy:
/// notice -> connection/network hero -> live metrics -> subscription summary.
///
/// Network state is never owned here. This file only maps the existing
/// controller state into the Litchi desktop presentation.
class DesktopDashboardHome extends StatelessWidget {
  const DesktopDashboardHome({
    super.key,
    required this.ctrl,
    required this.tick,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBar(notices: ctrl.notices, isLoading: ctrl.noticesLoading),
        if (noPlan)
          NoPlanCard(
            onPurchase: isPageEnabled(AppPage.shop)
                ? () => ctrl.goToPage(AppPage.shop)
                : null,
          )
        else ...[
          _TopControlRow(
            ctrl: ctrl,
            tick: tick,
            onToggleConnection: onToggleConnection,
            onProxyModeChanged: onProxyModeChanged,
            onNodeTap: onNodeTap,
          ),
          const SizedBox(height: AppSpacing.lg),
          _RealtimePanel(ctrl: ctrl, tick: tick),
          const SizedBox(height: AppSpacing.lg),
          _PlanPanel(ctrl: ctrl),
        ],
      ],
    );
  }
}

class _TopControlRow extends StatelessWidget {
  const _TopControlRow({
    required this.ctrl,
    required this.tick,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final connectionCard = _ConnectionHeroCard(
      ctrl: ctrl,
      tick: tick,
      onToggle: onToggleConnection,
      onNodeTap: onNodeTap,
    );
    final networkCard = _NetworkControlCard(
      ctrl: ctrl,
      onProxyModeChanged: onProxyModeChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (AppBreakpoints.isCompact(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              connectionCard,
              const SizedBox(height: AppSpacing.lg),
              networkCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 56, child: connectionCard),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 44, child: networkCard),
          ],
        );
      },
    );
  }
}

class _ConnectionHeroCard extends StatelessWidget {
  const _ConnectionHeroCard({
    required this.ctrl,
    required this.tick,
    required this.onToggle,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final ValueListenable<int> tick;
  final VoidCallback onToggle;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = ctrl.connectionStatus;
    final connected = status == ConnectionStatus.connected;
    final busy =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final supportsConnection = ctrl.supportsCoreConnection;
    final (statusText, statusColor) = !supportsConnection
        ? (context.l10n.businessEdition, c.textMuted)
        : switch (status) {
            ConnectionStatus.connected => (context.l10n.protected, c.primary),
            ConnectionStatus.connecting => (context.l10n.connecting, c.primary),
            ConnectionStatus.disconnecting => (
              context.l10n.disconnecting,
              c.textMuted,
            ),
            ConnectionStatus.error => (context.l10n.connectionFailed, c.danger),
            ConnectionStatus.disconnected => (
              context.l10n.notConnected,
              c.textMuted,
            ),
          };
    final connectionDescription = ctrl.networkMode == NetworkMode.tun
        ? context.l10n.tunDescription
        : context.l10n.systemProxyDescription;

    return AppCard(
      height: 228,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusDot(color: statusColor, busy: busy),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.heroStatus.copyWith(
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ValueListenableBuilder<int>(
                        valueListenable: tick,
                        builder: (context, _, _) => Text(
                          connected
                              ? formatDuration(ctrl.connectedDuration)
                              : context.l10n.currentNode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        connected
                            ? connectionDescription
                            : context.l10n.selectNodePrompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                LitchiConnectionOrb(
                  status: status,
                  enabled: !busy && supportsConnection,
                  onPressed: onToggle,
                  size: 136,
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: c.softBorder),
          const SizedBox(height: AppSpacing.md),
          _CompactNodeRow(
            node: ctrl.currentNode,
            loading: ctrl.isInitialLoading && ctrl.nodes.isEmpty,
            automatic: ctrl.autoSelected,
            onTap: onNodeTap,
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.busy});

  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return SizedBox.square(
        dimension: 11,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
      );
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _CompactNodeRow extends StatelessWidget {
  const _CompactNodeRow({
    required this.node,
    required this.loading,
    required this.automatic,
    required this.onTap,
  });

  final NodeModel node;
  final bool loading;
  final bool automatic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nodeName = node.name.isEmpty
        ? loading
              ? context.l10n.syncingNodes
              : context.l10n.selectNodePrompt
        : node.name;
    final secondary = node.englishName.isNotEmpty
        ? node.englishName
        : context.l10n.nodeModeLabel(
            automatic ? context.l10n.autoSelect : context.l10n.manualSelect,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              _NodeAvatar(node: node),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nodeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (!loading || node.name.isNotEmpty)
                NodeLatency(
                  latency: node.latency,
                  style: NodeLatencyStyle.badge,
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.chevronRight, size: 16, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkControlCard extends StatelessWidget {
  const _NetworkControlCard({
    required this.ctrl,
    required this.onProxyModeChanged,
  });

  final AppController ctrl;
  final ValueChanged<ProxyMode> onProxyModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: 228,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: LucideIcons.slidersHorizontal,
            title: context.l10n.networkSettings,
            subtitle: context.l10n.connectionMethod,
          ),
          const SizedBox(height: AppSpacing.lg),
          _ControlLabel(label: context.l10n.connectionMethod),
          const SizedBox(height: AppSpacing.sm),
          const NetworkModeSelector(height: 42),
          const SizedBox(height: AppSpacing.lg),
          _ControlLabel(label: context.l10n.proxyMode),
          const SizedBox(height: AppSpacing.sm),
          ModeStrip(
            selected: ctrl.proxyMode,
            onChanged: onProxyModeChanged,
            buttonHeight: 36,
            padding: AppSpacing.xs,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _IconTile(icon: icon, size: 32),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ControlLabel extends StatelessWidget {
  const _ControlLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.metricLabel.copyWith(color: c.textSecondary),
    );
  }
}

class _NodeAvatar extends StatelessWidget {
  const _NodeAvatar({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: node.code.isNotEmpty
          ? CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 25,
                height: 18,
                shape: RoundedRectangle(3),
              ),
            )
          : Icon(LucideIcons.globe2, color: c.iconMuted, size: 18),
    );
  }
}

class _RealtimePanel extends StatelessWidget {
  const _RealtimePanel({required this.ctrl, required this.tick});

  final AppController ctrl;
  final ValueListenable<int> tick;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return AppCard(
      height: 104,
      radius: AppRadius.card,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: ctrl.downBpsNotifier,
              builder: (context, value, _) => _LiveMetric(
                icon: LucideIcons.arrowDown,
                label: context.l10n.downloadSpeed,
                value: formatRate(value),
                active: connected,
              ),
            ),
          ),
          _MetricDivider(color: c.softBorder, height: 48),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: ctrl.upBpsNotifier,
              builder: (context, value, _) => _LiveMetric(
                icon: LucideIcons.arrowUp,
                label: context.l10n.uploadSpeed,
                value: formatRate(value),
                active: connected,
              ),
            ),
          ),
          _MetricDivider(color: c.softBorder, height: 48),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: tick,
              builder: (context, _, _) => _LiveMetric(
                icon: LucideIcons.clock,
                label: context.l10n.connectionDurationLabel,
                value: formatDuration(ctrl.connectedDuration),
                active: connected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  const _LiveMetric({
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
      opacity: active ? 1 : 0.58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            _MetricIcon(icon: icon),
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
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 17, color: c.primary),
    );
  }
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.ctrl});

  final AppController ctrl;

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

    return AppCard(
      height: 154,
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconTile(icon: LucideIcons.crown, size: 32),
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
              const SizedBox(width: AppSpacing.md),
              Text(
                total > 0
                    ? '${formatGb(used)} / ${formatGb(total)}'
                    : '--',
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _TrafficProgress(value: progress),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _PlanMetric(
                    icon: LucideIcons.database,
                    label: context.l10n.remainingTrafficLabel,
                    value: formatGb(remaining),
                  ),
                ),
                _MetricDivider(color: c.softBorder, height: 38),
                Expanded(
                  child: _PlanMetric(
                    icon: LucideIcons.chartColumn,
                    label: context.l10n.todayUsedLabel,
                    value: formatGb(ctrl.todayTrafficGb),
                  ),
                ),
                _MetricDivider(color: c.softBorder, height: 38),
                Expanded(
                  child: _PlanMetric(
                    icon: LucideIcons.calendarDays,
                    label: context.l10n.expiryTime,
                    value: expiry.date.isEmpty
                        ? context.l10n.permanent
                        : expiry.date,
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

class _TrafficProgress extends StatelessWidget {
  const _TrafficProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 8,
        color: c.surfaceMuted,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: c.brandGradient),
          ),
        ),
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    color: color,
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.size = 28});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: size * 0.5, color: c.primary),
    );
  }
}

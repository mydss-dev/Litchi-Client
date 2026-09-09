import 'package:country_flags/country_flags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../app/nav_destinations.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/utils/traffic_summary_text.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_switch.dart';
import '../../../shared/widgets/mode_strip.dart';
import '../../../shared/widgets/no_plan_card.dart';
import '../../../shared/widgets/node_latency.dart';
import '../../../shared/widgets/notice_bar.dart';
import 'network_settings_card.dart';

/// Desktop home information order:
/// notice -> connection/node controls -> live status -> subscription summary.
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
          _ConnectionOverviewPanel(
            ctrl: ctrl,
            onToggle: onToggleConnection,
            onProxyModeChanged: onProxyModeChanged,
            onNodeTap: onNodeTap,
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, _) => _RealtimePanel(ctrl: ctrl),
          ),
          const SizedBox(height: 12),
          _PlanPanel(ctrl: ctrl),
        ],
      ],
    );
  }
}

class _ConnectionOverviewPanel extends StatelessWidget {
  const _ConnectionOverviewPanel({
    required this.ctrl,
    required this.onToggle,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final VoidCallback onToggle;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = ctrl.connectionStatus;
    final connected = status == ConnectionStatus.connected;
    final switchOn = connected || status == ConnectionStatus.connecting;
    final busy =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final supportsConnection = ctrl.supportsCoreConnection;
    final (statusText, statusColor) = !supportsConnection
        ? (context.l10n.businessEdition, c.textMuted)
        : switch (status) {
            ConnectionStatus.connected => (context.l10n.protected, c.success),
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
    final modeDescription = ctrl.networkMode == NetworkMode.system
        ? context.l10n.systemProxyDescription
        : context.l10n.tunDescription;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconTile(icon: LucideIcons.wifi),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.l10n.connectionSettings,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              _StatusPill(label: statusText, color: statusColor, busy: busy),
              const SizedBox(width: 10),
              AppSwitch(
                value: switchOn,
                onChanged: busy || !supportsConnection
                    ? null
                    : (_) => onToggle(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _NodeSummary(
            node: ctrl.currentNode,
            loading: ctrl.isInitialLoading && ctrl.nodes.isEmpty,
            automatic: ctrl.autoSelected,
            onTap: onNodeTap,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final connectionMethod = _ControlGroup(
                label: context.l10n.connectionMethod,
                child: const NetworkModeSelector(height: 38),
              );
              final proxyMode = _ControlGroup(
                label: context.l10n.proxyMode,
                child: ModeStrip(
                  selected: ctrl.proxyMode,
                  onChanged: onProxyModeChanged,
                  buttonHeight: 30,
                  padding: 3,
                ),
              );

              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    connectionMethod,
                    const SizedBox(height: 10),
                    proxyMode,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: connectionMethod),
                  const SizedBox(width: 12),
                  Expanded(child: proxyMode),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(LucideIcons.info, size: 14, color: c.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  modeDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.busy,
  });

  final String label;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
            )
          else
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeSummary extends StatelessWidget {
  const _NodeSummary({
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
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            children: [
              _NodeAvatar(node: node),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.l10n.currentNode,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nodeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: c.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (loading && node.name.isEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 3,
                          color: c.primary,
                          backgroundColor: c.softBorder,
                        ),
                      )
                    else
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              NodeLatency(latency: node.latency, style: NodeLatencyStyle.badge),
              const SizedBox(width: 10),
              Text(
                context.l10n.switchNode,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 15, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: c.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 15, color: c.primary),
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
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: node.code.isNotEmpty
          ? CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 28,
                height: 20,
                shape: RoundedRectangle(3),
              ),
            )
          : Icon(LucideIcons.globe2, color: c.iconMuted, size: 20),
    );
  }
}

class _RealtimePanel extends StatelessWidget {
  const _RealtimePanel({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => ctrl.goToPage(AppPage.traffic),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 15, color: c.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.realtimeStatusLabel,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                context.l10n.viewUsageLabel,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 15, color: c.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LiveMetric(
                  icon: Icons.access_time_rounded,
                  label: context.l10n.connectionDurationLabel,
                  value: connected
                      ? formatDuration(ctrl.connectedDuration)
                      : '--:--:--',
                  active: connected,
                ),
              ),
              _MetricDivider(color: c.softBorder, height: 38),
              Expanded(
                child: _LiveMetric(
                  icon: LucideIcons.arrowUp,
                  label: context.l10n.uploadSpeed,
                  value: formatRate(ctrl.upBps),
                  active: connected,
                ),
              ),
              _MetricDivider(color: c.softBorder, height: 38),
              Expanded(
                child: _LiveMetric(
                  icon: LucideIcons.arrowDown,
                  label: context.l10n.downloadSpeed,
                  value: formatRate(ctrl.downBps),
                  active: connected,
                ),
              ),
            ],
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
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _MetricIcon(icon: icon),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                      fontSize: 14,
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
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: c.primary),
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

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _PlanMetric(
              icon: LucideIcons.calendarDays,
              label: context.l10n.expiryTime,
              value: expiry.date.isEmpty ? context.l10n.permanent : expiry.date,
              footer: expiry.days == null
                  ? context.l10n.subscriptionLongTerm
                  : '${expiry.days} ${context.l10n.daysUnit}',
            ),
          ),
          _MetricDivider(color: c.softBorder, height: 46),
          Expanded(
            child: _PlanMetric(
              icon: LucideIcons.chartColumn,
              label: context.l10n.todayUsedLabel,
              value: formatGb(ctrl.todayTrafficGb),
              footer: yesterdayComparisonText(
                context,
                usage: ctrl.trafficUsage,
                currentGb: ctrl.todayTrafficGb,
              ),
            ),
          ),
          _MetricDivider(color: c.softBorder, height: 46),
          Expanded(
            child: _PlanMetric(
              icon: LucideIcons.database,
              label: context.l10n.remainingTrafficLabel,
              value: formatGb(ctrl.traffic.remainGb),
              footer: context.l10n.totalTrafficLabel(
                formatGb(ctrl.traffic.totalGb),
              ),
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
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: color,
  );
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.footer,
  });

  final IconData icon;
  final String label;
  final String value;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _IconTile(icon: icon),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                footer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

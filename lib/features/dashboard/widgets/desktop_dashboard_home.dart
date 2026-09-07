import 'package:country_flags/country_flags.dart';
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
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_switch.dart';
import '../../../shared/widgets/mode_strip.dart';
import '../../../shared/widgets/no_plan_card.dart';
import '../../../shared/widgets/node_latency.dart';
import '../../../shared/widgets/notice_bar.dart';
import 'network_settings_card.dart';

/// Desktop-only home composition.
///
/// Information priority is intentionally: notice -> connection -> node/live
/// status -> subscription. Compact/mobile home keeps its existing flow.
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
    final hasNoticeSlot = ctrl.noticesLoading || ctrl.notices.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NoticeBar(notices: ctrl.notices, isLoading: ctrl.noticesLoading),
        if (hasNoticeSlot) const SizedBox(height: 12),
        if (noPlan)
          NoPlanCard(
            onPurchase: isPageEnabled(AppPage.shop)
                ? () => ctrl.goToPage(AppPage.shop)
                : null,
          )
        else
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NetworkControlCard(
                    ctrl: ctrl,
                    onToggle: onToggleConnection,
                    onProxyModeChanged: onProxyModeChanged,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      final width = (constraints.maxWidth - gap) / 2;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: width,
                            child: _NodeOverviewCard(
                              node: ctrl.currentNode,
                              loading:
                                  ctrl.isInitialLoading && ctrl.nodes.isEmpty,
                              automatic: ctrl.autoSelected,
                              onTap: onNodeTap,
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: width,
                            child: _RealtimeStatusCard(ctrl: ctrl),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _PlanSummaryCard(ctrl: ctrl),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _NetworkControlCard extends StatelessWidget {
  const _NetworkControlCard({
    required this.ctrl,
    required this.onToggle,
    required this.onProxyModeChanged,
  });

  final AppController ctrl;
  final VoidCallback onToggle;
  final ValueChanged<ProxyMode> onProxyModeChanged;

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
    final description = ctrl.networkMode == NetworkMode.system
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
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(LucideIcons.wifi, size: 15, color: c.primary),
              ),
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
              _InlineStatus(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final width = (constraints.maxWidth - gap) / 2;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: width,
                    child: _ControlGroup(
                      label: context.l10n.connectionMethod,
                      child: const NetworkModeSelector(height: 38),
                    ),
                  ),
                  const SizedBox(width: gap),
                  SizedBox(
                    width: width,
                    child: _ControlGroup(
                      label: context.l10n.proxyMode,
                      child: ModeStrip(
                        selected: ctrl.proxyMode,
                        onChanged: onProxyModeChanged,
                        buttonHeight: 30,
                        padding: 3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, size: 14, color: c.primary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            minHeight: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: statusColor,
                          ),
                        )
                      : Icon(
                          connected
                              ? LucideIcons.shieldCheck
                              : status == ConnectionStatus.error
                              ? LucideIcons.shieldOff
                              : LucideIcons.shield,
                          size: 16,
                          color: statusColor,
                        ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        connected
                            ? formatDuration(ctrl.connectedDuration)
                            : context.l10n.dashboardSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSwitch(
                  value: connected,
                  onChanged: busy || !supportsConnection
                      ? null
                      : (_) => onToggle(),
                ),
              ],
            ),
          ),
        ],
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
            color: c.textMuted,
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

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeOverviewCard extends StatelessWidget {
  const _NodeOverviewCard({
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

    return AppCard(
      height: 126,
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Icon(LucideIcons.server, size: 15, color: c.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.currentNode,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                context.l10n.switchNode,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 2),
              Icon(LucideIcons.chevronRight, size: 15, color: c.primary),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              _NodeAvatar(node: node),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nodeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                        fontSize: 16,
                      ),
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
                          color: c.textMuted,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              NodeLatency(
                latency: node.latency,
                style: NodeLatencyStyle.badge,
              ),
            ],
          ),
        ],
      ),
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
      width: 44,
      height: 44,
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
                width: 28,
                height: 20,
                shape: RoundedRectangle(3),
              ),
            )
          : Icon(LucideIcons.globe2, color: c.iconMuted, size: 20),
    );
  }
}

class _RealtimeStatusCard extends StatelessWidget {
  const _RealtimeStatusCard({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return AppCard(
      height: 126,
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 15, color: c.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.status,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(LucideIcons.clock3, size: 13, color: c.iconMuted),
              const SizedBox(width: 5),
              Text(
                connected ? formatDuration(ctrl.connectedDuration) : '--:--:--',
                style: AppTextStyles.caption.copyWith(
                  color: connected ? c.textSecondary : c.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _LiveMetric(
                  icon: LucideIcons.arrowUp,
                  label: context.l10n.uploadSpeed,
                  value: formatRate(ctrl.upBps),
                  active: connected,
                ),
              ),
              Container(width: 1, height: 42, color: c.softBorder),
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
      opacity: active ? 1 : 0.48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: c.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong.copyWith(
                color: c.textPrimary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSummaryCard extends StatelessWidget {
  const _PlanSummaryCard({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final expiry = _expiryInfo(ctrl);

    return AppCard(
      height: 90,
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
          _SummaryDivider(color: c.softBorder),
          Expanded(
            child: _PlanMetric(
              icon: LucideIcons.gauge,
              label: context.l10n.usage,
              value: formatGb(ctrl.todayTrafficGb),
              footer: context.l10n.recentDays(1),
            ),
          ),
          _SummaryDivider(color: c.softBorder),
          Expanded(
            child: _PlanMetric(
              icon: LucideIcons.database,
              label: context.l10n.remaining,
              value: formatGb(ctrl.traffic.remainGb),
              footer: context.l10n.usedTraffic(
                ctrl.traffic.usedGb.toStringAsFixed(0),
                ctrl.traffic.totalGb.toStringAsFixed(0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 46,
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
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(icon, size: 14, color: c.primary),
        ),
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
                  color: c.textMuted,
                  fontSize: 10.5,
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
                  color: c.textMuted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

({int? days, String date}) _expiryInfo(AppController ctrl) {
  final expiredAt = ctrl.expiredAt;
  if (expiredAt != null && expiredAt > 0) {
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
    return (days: _daysUntil(expiry), date: formatDate(expiry));
  }

  final expiry = DateTime.tryParse(ctrl.user.expiry);
  if (expiry == null) return (days: null, date: '');
  return (days: _daysUntil(expiry), date: formatDate(expiry));
}

int _daysUntil(DateTime expiry) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(expiry.year, expiry.month, expiry.day);
  return end.difference(start).inDays.clamp(0, 9999);
}

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
/// notice -> connection/node + network settings -> realtime status -> subscription summary.
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
          ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (context, _, _) => _TopControlRow(
              ctrl: ctrl,
              onToggleConnection: onToggleConnection,
              onProxyModeChanged: onProxyModeChanged,
              onNodeTap: onNodeTap,
            ),
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

class _TopControlRow extends StatelessWidget {
  const _TopControlRow({
    required this.ctrl,
    required this.onToggleConnection,
    required this.onProxyModeChanged,
    required this.onNodeTap,
  });

  final AppController ctrl;
  final VoidCallback onToggleConnection;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final VoidCallback onNodeTap;

  @override
  Widget build(BuildContext context) {
    final connectionCard = _ConnectionNodeCard(
      ctrl: ctrl,
      onToggle: onToggleConnection,
      onNodeTap: onNodeTap,
    );
    final networkCard = _NetworkSettingsCard(
      ctrl: ctrl,
      onProxyModeChanged: onProxyModeChanged,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              connectionCard,
              const SizedBox(height: 12),
              networkCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: connectionCard),
            const SizedBox(width: 12),
            Expanded(child: networkCard),
          ],
        );
      },
    );
  }
}

class _ConnectionNodeCard extends StatelessWidget {
  const _ConnectionNodeCard({
    required this.ctrl,
    required this.onToggle,
    required this.onNodeTap,
  });

  final AppController ctrl;
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
    final switchOn = connected || status == ConnectionStatus.connecting;
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

    return AppCard(
      height: 184,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (busy)
                          SizedBox(
                            width: 9,
                            height: 9,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: statusColor,
                            ),
                          )
                        else
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: statusColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      connected
                          ? formatDuration(ctrl.connectedDuration)
                          : context.l10n.currentNode,
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
              const SizedBox(width: 8),
              AppSwitch(
                value: switchOn,
                onChanged: busy || !supportsConnection
                    ? null
                    : (_) => onToggle(),
              ),
            ],
          ),
          const Spacer(),
          Divider(height: 1, thickness: 1, color: c.softBorder),
          const SizedBox(height: 12),
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
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              _NodeAvatar(node: node),
              const SizedBox(width: 10),
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
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      secondary,
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
              const SizedBox(width: 8),
              if (!loading || node.name.isNotEmpty)
                NodeLatency(
                  latency: node.latency,
                  style: NodeLatencyStyle.badge,
                ),
              const SizedBox(width: 7),
              Text(
                context.l10n.switchNode,
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(
                  color: c.primary,
                  fontSize: 11,
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

class _NetworkSettingsCard extends StatelessWidget {
  const _NetworkSettingsCard({
    required this.ctrl,
    required this.onProxyModeChanged,
  });

  final AppController ctrl;
  final ValueChanged<ProxyMode> onProxyModeChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      height: 184,
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            icon: LucideIcons.activity,
            title: context.l10n.networkSettings,
          ),
          const SizedBox(height: 12),
          _ControlLabel(label: context.l10n.connectionMethod),
          const SizedBox(height: 5),
          const NetworkModeSelector(height: 34),
          const SizedBox(height: 10),
          _ControlLabel(label: context.l10n.proxyMode),
          const SizedBox(height: 5),
          ModeStrip(
            selected: ctrl.proxyMode,
            onChanged: onProxyModeChanged,
            buttonHeight: 28,
            padding: 3,
          ),
        ],
      ),
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
      style: AppTextStyles.caption.copyWith(
        color: c.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _IconTile(icon: icon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
              color: c.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
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
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 14, color: c.primary),
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
        color: c.cardBg,
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
  const _RealtimePanel({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final connected = ctrl.connectionStatus == ConnectionStatus.connected;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 15, color: c.primary),
              const SizedBox(width: 7),
              Text(
                context.l10n.realtimeStatusLabel,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  : _remainingDaysText(context, expiry.days!),
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

String _remainingDaysText(BuildContext context, int days) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'zh') {
    final traditional = locale.countryCode?.toUpperCase() == 'TW';
    return '${traditional ? '剩餘' : '剩余'} $days ${context.l10n.daysUnit}';
  }
  return context.l10n.subscriptionExpiresInDays(days);
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../shared/config/app_config.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'mobile_node_picker_sheet.dart';
import 'mobile_page_header.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  Timer? _tickTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    if (ctrl.coreRunning && _tickTimer == null) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!ctrl.coreRunning && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  Future<void> _toggleConnection() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();
    if (!mounted) return;

    if (error != null && error.isNotEmpty) {
      AppToast.show(context, error, type: AppToastType.error);
    } else if (ctrl.coreRunning) {
      AppToast.show(context, '连接成功', type: AppToastType.success);
    }
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatTrafficGb(double gb) {
    if (gb <= 0) return '0.0 GB';
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _MobileHeader(connected: ctrl.coreRunning),
          const SizedBox(height: 16),
          if (ctrl.dataLoadError != null) ...[
            _InlineNotice(
              icon: LucideIcons.circleAlert,
              text: ctrl.dataLoadError!,
              color: c.warning,
            ),
            const SizedBox(height: 12),
          ],
          _MobileConnectionCard(
            status: ctrl.connectionStatus,
            node: ctrl.currentNode,
            proxyMode: ctrl.proxyMode,
            automatic: ctrl.autoSelected,
            elapsedLabel: _formatDuration(ctrl.connectedDuration),
            supportsConnection: ctrl.supportsCoreConnection,
            onToggle: _toggleConnection,
            onNodesTap: () => showMobileNodePicker(context),
          ),
          if (ctrl.connectionStatus == ConnectionStatus.error &&
              ctrl.coreError.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InlineNotice(
              icon: LucideIcons.circleX,
              text: ctrl.coreError,
              color: c.danger,
            ),
          ],
          const SizedBox(height: 14),
          _ModeStrip(
            selected: ctrl.proxyMode,
            onChanged: (mode) {
              if (mode == ctrl.proxyMode) return;
              ctrl.setProxyMode(mode);
              AppToast.show(
                context,
                mode.switchToast,
                type: AppToastType.success,
              );
            },
          ),
          const SizedBox(height: 14),
          _HomeCardGrid(
            ctrl: ctrl,
            formatTrafficGb: _formatTrafficGb,
          ),
        ],
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Row(
      children: [
        Expanded(
          child: MobilePageHeader(
            title: '首页',
            subtitle: '网络状态与节点连接',
            trailing: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: connected
                    ? c.success.withValues(alpha: 0.12)
                    : c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.softBorder),
              ),
              child: Icon(
                connected ? LucideIcons.shieldCheck : LucideIcons.shield,
                color: connected ? c.success : c.iconMuted,
                size: 19,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileConnectionCard extends StatelessWidget {
  const _MobileConnectionCard({
    required this.status,
    required this.node,
    required this.proxyMode,
    required this.automatic,
    required this.elapsedLabel,
    required this.supportsConnection,
    required this.onToggle,
    required this.onNodesTap,
  });

  final ConnectionStatus status;
  final NodeModel node;
  final ProxyMode proxyMode;
  final bool automatic;
  final String elapsedLabel;
  final bool supportsConnection;
  final VoidCallback onToggle;
  final VoidCallback onNodesTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isBusy =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final (statusText, statusColor) = !supportsConnection
        ? ('业务版', c.textMuted)
        : switch (status) {
            ConnectionStatus.connected => ('保护中', c.success),
            ConnectionStatus.connecting => ('连接中', c.primary),
            ConnectionStatus.disconnecting => ('断开中', c.textMuted),
            ConnectionStatus.error => ('连接失败', c.danger),
            ConnectionStatus.disconnected => ('未连接', c.textMuted),
          };
    final actionText = !supportsConnection
        ? '暂未开放'
        : switch (status) {
            ConnectionStatus.connected => '断开连接',
            ConnectionStatus.connecting => '正在连接',
            ConnectionStatus.disconnecting => '正在断开',
            ConnectionStatus.error => '重新连接',
            ConnectionStatus.disconnected => '开始连接',
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.card(c),
      ),
      child: Column(
        children: [
          Row(
            children: [_StatusPill(label: statusText, color: statusColor)],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: isBusy || !supportsConnection ? null : onToggle,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: status == ConnectionStatus.connected
                    ? c.brandGradient
                    : null,
                color: status == ConnectionStatus.connected
                    ? null
                    : c.surfaceMuted,
                boxShadow: status == ConnectionStatus.connected
                    ? AppShadows.powerButton
                    : AppShadows.soft(c),
                border: Border.all(
                  color: status == ConnectionStatus.connected
                      ? Colors.white.withValues(alpha: 0.3)
                      : c.softBorder,
                  width: 1,
                ),
              ),
              child: Center(
                child: isBusy
                    ? CircularProgressIndicator(
                        strokeWidth: 3,
                        color: c.primary,
                      )
                    : Icon(
                        LucideIcons.power,
                        size: 46,
                        color: status == ConnectionStatus.connected
                            ? Colors.white
                            : c.primary,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            actionText,
            style: AppTextStyles.sectionTitle.copyWith(
              color: statusColor == c.textMuted ? c.textPrimary : statusColor,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: Center(
              child: Text(
                status == ConnectionStatus.connected
                    ? elapsedLabel
                    : !supportsConnection
                    ? '当前 Android 版本先提供登录、购买和节点查看'
                    : '',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onNodesTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: c.softBorder),
              ),
              child: Row(
                children: [
                  _NodeAvatar(node: node),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.name.isEmpty ? '请选择节点' : node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: c.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '节点模式：${automatic ? '自动选择' : '手动选择'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _LatencyBadge(latency: node.latency),
                  const SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 18, color: c.iconMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge({required this.latency});

  final int latency;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color) = switch (latency) {
      > 0 && < 150 => ('$latency ms', c.success),
      > 0 && < 9999 => ('$latency ms', c.warning),
      >= 9999 => ('超时', c.danger),
      _ => ('', c.textMuted),
    };
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatRate(int bps) {
  if (bps <= 0) return '0 KB/s';
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bps >= mb) return '${(bps / mb).toStringAsFixed(1)} MB/s';
  if (bps >= kb) return '${(bps / kb).toStringAsFixed(0)} KB/s';
  return '$bps B/s';
}

class _ModeStrip extends StatelessWidget {
  const _ModeStrip({required this.selected, required this.onChanged});

  final ProxyMode selected;
  final ValueChanged<ProxyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final mode in ProxyMode.values)
            Expanded(
              child: _ModeButton(
                label: switch (mode) {
                  ProxyMode.rule => '规则',
                  ProxyMode.global => '全局',
                  ProxyMode.direct => '直连',
                },
                selected: selected == mode,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          height: 42,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: selected ? AppShadows.soft(c) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.bodyStrong.copyWith(
                color: selected ? c.primary : c.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeCardGrid extends StatelessWidget {
  const _HomeCardGrid({
    required this.ctrl,
    required this.formatTrafficGb,
  });

  final AppController ctrl;
  final String Function(double) formatTrafficGb;

  @override
  Widget build(BuildContext context) {
    final cards = AppConfig.mobileHomeCards.take(4).toList();
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: _HomeConfigCard(
                config: cards[i],
                ctrl: ctrl,
                formatTrafficGb: formatTrafficGb,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < cards.length
                  ? _HomeConfigCard(
                      config: cards[i + 1],
                      ctrl: ctrl,
                      formatTrafficGb: formatTrafficGb,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < cards.length) rows.add(const SizedBox(height: 10));
    }

    return Column(children: rows);
  }
}

class _HomeConfigCard extends StatelessWidget {
  const _HomeConfigCard({
    required this.config,
    required this.ctrl,
    required this.formatTrafficGb,
  });

  final MobileHomeCardConfig config;
  final AppController ctrl;
  final String Function(double) formatTrafficGb;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final icon = _homeCardIcon(config.icon, config.type);
    final title = config.title.isEmpty ? _homeCardTitle(config.type) : config.title;

    if (config.type == 'downSpeed') {
      return ValueListenableBuilder<int>(
        valueListenable: ctrl.downBpsNotifier,
        builder: (context, value, _) => _MetricCard(
          icon: icon,
          label: title,
          value: _formatRate(value),
          color: c.primary,
        ),
      );
    }

    if (config.type == 'upSpeed') {
      return ValueListenableBuilder<int>(
        valueListenable: ctrl.upBpsNotifier,
        builder: (context, value, _) => _MetricCard(
          icon: icon,
          label: title,
          value: _formatRate(value),
          color: c.primary,
        ),
      );
    }

    return _MetricCard(
      icon: icon,
      label: title,
      value: _homeCardValue(config.type, ctrl, formatTrafficGb),
      color: c.primary,
    );
  }
}

String _homeCardValue(
  String type,
  AppController ctrl,
  String Function(double) formatTrafficGb,
) {
  return switch (type) {
    'currentPlan' => ctrl.user.plan.isEmpty ? '--' : ctrl.user.plan,
    'remainTraffic' => formatTrafficGb(ctrl.traffic.remainGb),
    'todayTraffic' => formatTrafficGb(ctrl.todayTrafficGb),
    'resetDay' => _formatResetDay(ctrl.resetDay),
    'deviceLimit' => _formatDeviceLimit(ctrl.deviceLimit),
    'expireDate' => ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
    _ => '--',
  };
}

String _homeCardTitle(String type) {
  return switch (type) {
    'currentPlan' => '当前套餐',
    'remainTraffic' => '剩余流量',
    'todayTraffic' => '今日流量',
    'downSpeed' => '下行速率',
    'upSpeed' => '上行速率',
    'resetDay' => '流量重置',
    'deviceLimit' => '设备数',
    'expireDate' => '到期时间',
    _ => '信息',
  };
}

String _formatResetDay(int? resetDay) {
  if (resetDay == null || resetDay == 0) return '--';
  return '每月 $resetDay 日';
}

String _formatDeviceLimit(int? deviceLimit) {
  if (deviceLimit == null) return '--';
  return deviceLimit > 0 ? '$deviceLimit 台' : '不限';
}

IconData _homeCardIcon(String icon, String type) {
  final name = icon.isEmpty ? type : icon;
  return switch (name) {
    'package' => LucideIcons.package,
    'gauge' => LucideIcons.gauge,
    'calendarDays' => LucideIcons.calendarDays,
    'calendarClock' => LucideIcons.calendarClock,
    'refreshCw' => LucideIcons.refreshCw,
    'download' => LucideIcons.download,
    'upload' => LucideIcons.upload,
    'smartphone' => LucideIcons.smartphone,
    'timer' => LucideIcons.timer,
    'activity' => LucideIcons.activity,
    'zap' => LucideIcons.zap,
    'currentPlan' => LucideIcons.package,
    'remainTraffic' => LucideIcons.gauge,
    'todayTraffic' => LucideIcons.calendarDays,
    'downSpeed' => LucideIcons.download,
    'upSpeed' => LucideIcons.upload,
    'resetDay' => LucideIcons.refreshCw,
    'deviceLimit' => LucideIcons.smartphone,
    'expireDate' => LucideIcons.calendarClock,
    _ => LucideIcons.gauge,
  };
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 78,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: c.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusDot(color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
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
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Text(
        node.flag.isEmpty ? '·' : node.flag,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../config/mobile_layout.dart';
import '../../shared/models/app_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/mode_strip.dart';
import '../../shared/widgets/page_header.dart';
import '../mobile/mobile_node_picker_sheet.dart';
import '../mobile/mobile_page_header.dart';
import 'widgets/connection_hero_card.dart';
import 'widgets/connection_stats_row.dart';
import 'widgets/error_banner.dart';
import 'widgets/expiry_banner.dart';
import 'widgets/network_settings_card.dart';
import 'widgets/proxy_mode_card.dart';

/// Dashboard / Home — a single responsive page.
///
/// Two-layout merge. Wide keeps the desktop dashboard (hero + mini cards +
/// stats row); compact keeps the mobile home (pull-to-refresh, connection card,
/// mode strip, card grid). The 1-second uptime ticker (`_tickTimer`/`_syncTimer`)
/// and formatters are in `shared/utils/formatters.dart`; `ModeStrip` lives in
/// `shared/widgets/mode_strip.dart`. The mobile `_syncTimer` (with a mounted
/// guard) is kept for both. Wide/compact action handlers are distinct. There are
/// no sub-widget name collisions, so nothing is renamed. Split on window width.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _tickTimer;
  // Ticks once per second to refresh ONLY the elapsed-time readout, instead of
  // rebuilding the whole page 60x/minute while connected. ctrl-driven changes
  // (status, data) still rebuild the page via AppScope (InheritedNotifier).
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tick.dispose();
    super.dispose();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    if (ctrl.coreRunning && _tickTimer == null) {
      _tickTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick.value++,
      );
    } else if (!ctrl.coreRunning && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  // ── Wide-branch actions ────────────────────────────────────────────────
  Future<void> _onToggle() async {
    final ctrl = AppScope.of(context);
    if (ctrl.connectionActionLocked) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();

    if (mounted && error != null) {
      AppToast.show(context, error, type: AppToastType.error);
    } else if (mounted && ctrl.coreRunning) {
      AppToast.show(context, '连接成功', type: AppToastType.success);
    }
  }

  Future<void> _onRefreshData() async {
    await AppScope.of(context).refreshData();
  }

  // ── Compact-branch actions ─────────────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return context.isCompact ? _buildCompact(context) : _buildWide(context);
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    final ctrl = AppScope.of(context);
    final status = ctrl.connectionStatus;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '首页', subtitle: '查看当前连接、节点与流量状态'),
          const SizedBox(height: 12),
          ExpiryBanner(user: ctrl.user),
          if (ctrl.dataLoadError != null) ...[
            ErrorBanner(
              message: ctrl.dataLoadError!,
              onRetry: _onRefreshData,
              warning: true,
            ),
            const SizedBox(height: 12),
          ],
          ValueListenableBuilder<int>(
            valueListenable: _tick,
            builder: (context, _, _) => ConnectionHeroCard(
              status: status,
              elapsedLabel: formatDuration(ctrl.connectedDuration),
              onToggle: _onToggle,
            ),
          ),
          if (status == ConnectionStatus.error &&
              ctrl.coreError.isNotEmpty) ...[
            const SizedBox(height: 8),
            ErrorBanner(message: ctrl.coreError, onRetry: _onToggle),
          ],
          const SizedBox(height: 12),
          const _InfoMiniCardsRow(),
          const SizedBox(height: 12),
          const ConnectionStatsRow(),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _MobileHeader(connected: ctrl.coreRunning),
          const SizedBox(height: 12),
          if (ctrl.dataLoadError != null) ...[
            _InlineNotice(
              icon: LucideIcons.circleAlert,
              text: ctrl.dataLoadError!,
              color: c.warning,
            ),
            const SizedBox(height: 12),
          ],
          ValueListenableBuilder<int>(
            valueListenable: _tick,
            builder: (context, _, _) => _MobileConnectionCard(
              status: ctrl.connectionStatus,
              node: ctrl.currentNode,
              proxyMode: ctrl.proxyMode,
              automatic: ctrl.autoSelected,
              elapsedLabel: formatDuration(ctrl.connectedDuration),
              supportsConnection: ctrl.supportsCoreConnection,
              onToggle: _toggleConnection,
              onNodesTap: () => showMobileNodePicker(context),
            ),
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
          const SizedBox(height: 10),
          ModeStrip(
            selected: ctrl.proxyMode,
            onChanged: (mode) async {
              if (mode == ctrl.proxyMode) return;
              final error = await ctrl.setProxyMode(mode);
              if (!context.mounted) return;
              if (error != null) {
                AppToast.show(
                  context,
                  error,
                  type: AppToastType.error,
                );
              } else {
                AppToast.show(
                  context,
                  mode.switchToast,
                  type: AppToastType.success,
                );
              }
            },
          ),
          const SizedBox(height: 10),
          _HomeCardGrid(
            ctrl: ctrl,
            formatTrafficGb: formatTrafficGb,
          ),
        ],
      ),
    );
  }
}

// ── Wide-layout widgets (original desktop DashboardPage, verbatim) ────────

class _InfoMiniCardsRow extends StatelessWidget {
  const _InfoMiniCardsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 380) {
          return const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: ProxyModeCard()),
                SizedBox(width: 14),
                Expanded(child: NetworkSettingsCard()),
              ],
            ),
          );
        }
        return const Column(
          children: [
            ProxyModeCard(),
            SizedBox(height: 14),
            NetworkSettingsCard(),
          ],
        );
      },
    );
  }
}

// ── Compact-layout widgets (original MobileHomePage, verbatim) ────────────

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
          _MobilePowerButton(
            status: status,
            disabled: isBusy || !supportsConnection,
            onTap: onToggle,
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

class _HomeCardGrid extends StatelessWidget {
  const _HomeCardGrid({
    required this.ctrl,
    required this.formatTrafficGb,
  });

  final AppController ctrl;
  final String Function(double) formatTrafficGb;

  @override
  Widget build(BuildContext context) {
    final cards = MobileLayout.homeCards.take(4).toList();
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
    final icon = homeCardIcon(config.icon, config.type);
    final title = config.title.isEmpty ? homeCardTitle(config.type) : config.title;

    if (config.type == 'downSpeed') {
      return ValueListenableBuilder<int>(
        valueListenable: ctrl.downBpsNotifier,
        builder: (context, value, _) => _MetricCard(
          icon: icon,
          label: title,
          value: formatRate(value),
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
          value: formatRate(value),
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
    'resetDay' => formatResetDay(ctrl.resetDay),
    'deviceLimit' => formatDeviceLimit(ctrl.deviceLimit),
    'expireDate' => ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
    _ => '--',
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

class _MobilePowerButton extends StatefulWidget {
  const _MobilePowerButton({
    required this.status,
    required this.disabled,
    required this.onTap,
  });

  final ConnectionStatus status;
  final bool disabled;
  final VoidCallback onTap;

  @override
  State<_MobilePowerButton> createState() => _MobilePowerButtonState();
}

class _MobilePowerButtonState extends State<_MobilePowerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  bool get _connected => widget.status == ConnectionStatus.connected;
  bool get _transitioning =>
      widget.status == ConnectionStatus.connecting ||
      widget.status == ConnectionStatus.disconnecting;
  bool get _shouldPulse => _transitioning;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _MobilePowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    if (_shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!_shouldPulse && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final disconnecting = widget.status == ConnectionStatus.disconnecting;
    final pulseColor = disconnecting ? c.textMuted : c.primary;

    return GestureDetector(
      onTap: widget.disabled ? null : widget.onTap,
      onTapDown: widget.disabled
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.disabled
          ? null
          : () => setState(() => _pressed = false),
      child: SizedBox(
        width: 152,
        height: 152,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_shouldPulse)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_pulseController.value);
                  return Container(
                    width: 126 + 26 * t,
                    height: 126 + 26 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pulseColor.withValues(alpha: 0.18 * (1 - t)),
                      border: Border.all(
                        color: pulseColor.withValues(alpha: 0.24 * (1 - t)),
                      ),
                    ),
                  );
                },
              ),
            AnimatedScale(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              scale: widget.disabled ? 0.96 : (_pressed ? 0.92 : 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _connected ? c.brandGradient : null,
                  color: _connected ? null : c.surfaceMuted,
                  boxShadow: _connected
                      ? AppShadows.powerButton
                      : AppShadows.soft(c),
                  border: Border.all(
                    color: _connected
                        ? Colors.white.withValues(alpha: 0.3)
                        : c.softBorder,
                  ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.88,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _transitioning
                        ? SizedBox(
                            key: ValueKey(widget.status),
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: pulseColor,
                            ),
                          )
                        : Icon(
                            LucideIcons.power,
                            key: ValueKey(widget.status),
                            size: 46,
                            color: _connected ? Colors.white : c.primary,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

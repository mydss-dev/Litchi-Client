import 'dart:async';
import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../app/core_error_message_service.dart';
import '../../app/nav_destinations.dart';
import '../../config/mobile_layout.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/mode_strip.dart';
import '../../shared/widgets/no_plan_card.dart';
import '../../shared/widgets/node_latency.dart';
import '../../shared/widgets/notice_carousel.dart';
import '../../shared/widgets/update_banner.dart';
import '../nodes/node_picker.dart';
import 'widgets/error_banner.dart';

/// Dashboard / Home — the mobile home page.
///
/// Pull-to-refresh, connection card, mode strip, card grid. The 1-second uptime
/// ticker (`_tickTimer`/`_syncTimer`) and formatters are in
/// `shared/utils/formatters.dart`; `ModeStrip` lives in
/// `shared/widgets/mode_strip.dart`.
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
    final shouldRun = ctrl.page == AppPage.dashboard && ctrl.coreRunning;
    if (shouldRun && _tickTimer == null) {
      _tickTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick.value++,
      );
    } else if (!shouldRun && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  // ── Connection actions ─────────────────────────────────────────────────
  Future<void> _toggleConnection() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();
    if (!mounted) return;

    if ((error == null || error.isEmpty) && ctrl.coreRunning) {
      AppToast.show(
        context,
        context.l10n.connectionSuccess,
        type: AppToastType.success,
      );
    }
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    return _buildCompact(context);
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final noPlan =
        ctrl.hasAccountSummary && !ctrl.isInitialLoading && !ctrl.hasPlan;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (ctrl.updateInfo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RevealIn(
                child: UpdateBanner(
                  info: ctrl.updateInfo!,
                  onDismiss: ctrl.dismissUpdate,
                ),
              ),
            ),
          if (ctrl.notices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RevealIn(
                child: NoticeCarousel(notices: ctrl.notices),
              ),
            ),
          _DashboardAlerts(
            ctrl: ctrl,
            onConnectionRetry: _toggleConnection,
            onDataRetry: _handlePullRefresh,
          ),
          if (noPlan)
            NoPlanCard(
              onPurchase: isPageEnabled(AppPage.shop)
                  ? () => ctrl.goToPage(AppPage.shop)
                  : null,
            )
          else ...[
            ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (context, _, _) => _MobileConnectionCard(
                status: ctrl.connectionStatus,
                node: ctrl.currentNode,
                loading: ctrl.isInitialLoading && ctrl.nodes.isEmpty,
                proxyMode: ctrl.proxyMode,
                automatic: ctrl.autoSelected,
                elapsedLabel: formatDuration(ctrl.connectedDuration),
                supportsConnection: ctrl.supportsCoreConnection,
                onToggle: _toggleConnection,
                onNodesTap: () => showNodePicker(context),
              ),
            ),
            const SizedBox(height: 10),
            ModeStrip(
              selected: ctrl.proxyMode,
              onChanged: (mode) async {
                if (mode == ctrl.proxyMode) return;
                final error = await ctrl.setProxyMode(mode);
                if (!context.mounted) return;
                if (error != null) {
                  AppToast.show(context, error, type: AppToastType.error);
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
            _HomeCardGrid(ctrl: ctrl, formatTrafficGb: formatTrafficGb),
          ],
        ],
      ),
    );
  }
}

// ── Shared alert banner ──────────────────────────────────────────────────────

class _DashboardAlerts extends StatelessWidget {
  const _DashboardAlerts({
    required this.ctrl,
    required this.onConnectionRetry,
    required this.onDataRetry,
  });

  final AppController ctrl;
  final VoidCallback onConnectionRetry;
  final VoidCallback onDataRetry;

  @override
  Widget build(BuildContext context) {
    final alerts = <Widget>[
      if (ctrl.connectionStatus == ConnectionStatus.error &&
          ctrl.coreError.isNotEmpty)
        ErrorBanner(
          message: CoreErrorMessageService.userFacing(
            ctrl.coreError,
            l10n: context.l10n,
          ),
          onRetry: onConnectionRetry,
        ),
      if (ctrl.dataLoadError != null)
        ErrorBanner(
          message: ctrl.nodes.isNotEmpty
              ? context.l10n.cachedModeActive
              : context.l10n.serverUnavailableNoCache,
          onRetry: onDataRetry,
          warning: true,
        ),
    ];

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          for (var index = 0; index < alerts.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            alerts[index],
          ],
        ],
      ),
    );
  }
}

// ── Startup reveal (fade-in) ────────────────────────────────────────────────

/// Fades and slides its child in on first build, so the update banner and
/// notice carousel appear smoothly on launch instead of popping in.
class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 14),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ── Compact-layout widgets (original MobileHomePage, verbatim) ────────────

class _MobileConnectionCard extends StatelessWidget {
  const _MobileConnectionCard({
    required this.status,
    required this.node,
    required this.loading,
    required this.proxyMode,
    required this.automatic,
    required this.elapsedLabel,
    required this.supportsConnection,
    required this.onToggle,
    required this.onNodesTap,
  });

  final ConnectionStatus status;
  final NodeModel node;
  final bool loading;
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
    final actionText = !supportsConnection
        ? context.l10n.unavailable
        : switch (status) {
            ConnectionStatus.connected => context.l10n.disconnectConnection,
            ConnectionStatus.connecting => context.l10n.connecting,
            ConnectionStatus.disconnecting => context.l10n.disconnecting,
            ConnectionStatus.error => context.l10n.reconnect,
            ConnectionStatus.disconnected => context.l10n.startConnection,
          };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      radius: AppRadius.xl,
      child: Column(
        children: [
          Row(
            children: [
              _StatusPill(
                status: status,
                label: statusText,
                color: statusColor,
              ),
            ],
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
                    ? context.l10n.androidLimitedNotice
                    : '',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNodesTap,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Ink(
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
                            node.name.isEmpty
                                ? loading
                                      ? context.l10n.syncingNodes
                                      : context.l10n.selectNodePrompt
                                : node.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: c.textPrimary,
                              fontSize: 15,
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
                              context.l10n.nodeModeLabel(
                                automatic
                                    ? context.l10n.autoSelect
                                    : context.l10n.manualSelect,
                              ),
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
                    NodeLatency(
                      latency: node.latency,
                      style: NodeLatencyStyle.badge,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: c.iconMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCardGrid extends StatelessWidget {
  const _HomeCardGrid({required this.ctrl, required this.formatTrafficGb});

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
    final title = config.title.isEmpty
        ? homeCardTitle(config.type)
        : config.title;

    return _MetricCard(
      icon: icon,
      label: title,
      value: _homeCardValue(config.type, ctrl, formatTrafficGb),
      color: c.primary,
      loading:
          ctrl.isInitialLoading &&
          !ctrl.hasAccountSummary &&
          _isAccountMetric(config.type),
    );
  }
}

bool _isAccountMetric(String type) => switch (type) {
  'currentPlan' ||
  'remainTraffic' ||
  'resetDay' ||
  'deviceLimit' ||
  'expireDate' => true,
  _ => false,
};

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
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      height: 78,
      padding: const EdgeInsets.all(13),
      shadow: AppCardShadow.none,
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
                if (loading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SizedBox(
                      width: 72,
                      height: 6,
                      child: LinearProgressIndicator(
                        color: color,
                        backgroundColor: c.softBorder,
                      ),
                    ),
                  )
                else
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
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _chargeController;
  late final AnimationController _successController;
  bool _pressed = false;

  bool get _connected => widget.status == ConnectionStatus.connected;
  bool get _connecting => widget.status == ConnectionStatus.connecting;
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
    _chargeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _syncPulse();
    _syncCharge();
  }

  @override
  void didUpdateWidget(covariant _MobilePowerButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
    _syncCharge();
    // Fire the success burst once when we land on "connected".
    if (_connected && oldWidget.status != ConnectionStatus.connected) {
      _successController.forward(from: 0);
    }
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

  void _syncCharge() {
    if (_connecting && !_chargeController.isAnimating) {
      _chargeController.repeat();
    } else if (!_connecting && _chargeController.isAnimating) {
      _chargeController.stop();
      _chargeController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _chargeController.dispose();
    _successController.dispose();
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
        width: 148,
        height: 148,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (_shouldPulse)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(_pulseController.value);
                  return Container(
                    width: 124 + 24 * t,
                    height: 124 + 24 * t,
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
            // Success glow + radiating rings, behind the button.
            AnimatedBuilder(
              animation: _successController,
              builder: (context, _) => _buildSuccessBurst(c),
            ),
            AnimatedBuilder(
              animation: _successController,
              builder: (context, child) {
                final t = _successController.value;
                return Transform.scale(
                  scale: 1 + 0.07 * math.sin(t * math.pi),
                  child: child,
                );
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                scale: widget.disabled ? 0.96 : (_pressed ? 0.92 : 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  width: 124,
                  height: 124,
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
                          : c.border,
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
                          ? _ChargingRing(
                              key: ValueKey(widget.status),
                              turns: _chargeController,
                              color: pulseColor,
                            )
                          : Icon(
                              LucideIcons.power,
                              key: ValueKey(widget.status),
                              size: 42,
                              color: _connected ? Colors.white : c.primary,
                            ),
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

  Widget _buildSuccessBurst(AppColors c) {
    final t = _successController.value;
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 124 + 24 * t,
          height: 124 + 24 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.success.withValues(alpha: 0.20 * (1 - t)),
          ),
        ),
        for (var i = 0; i < 2; i++) _successRing(c, t, i),
      ],
    );
  }

  Widget _successRing(AppColors c, double t, int i) {
    final progress = ((t - i * 0.10) / 0.90).clamp(0.0, 1.0);
    if (progress <= 0 || progress >= 1) return const SizedBox.shrink();
    final size = 124 + progress * 44;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: c.success.withValues(alpha: 0.45 * (1 - progress)),
          width: 2,
        ),
      ),
    );
  }
}

class _ChargingRing extends StatelessWidget {
  const _ChargingRing({
    super.key,
    required this.turns,
    required this.color,
  });

  final Animation<double> turns;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: turns,
      child: SizedBox(
        width: 46,
        height: 46,
        child: CircularProgressIndicator(
          value: 0.33,
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          color: color,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.label,
    required this.color,
  });

  final ConnectionStatus status;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      ConnectionStatus.connected => LucideIcons.shieldCheck,
      ConnectionStatus.connecting => LucideIcons.shield,
      ConnectionStatus.disconnected => LucideIcons.shield,
      ConnectionStatus.disconnecting ||
      ConnectionStatus.error => LucideIcons.shieldOff,
    };
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
          Icon(icon, size: 14, color: color),
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

import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Local tick-timer to update the elapsed display every second.
  Timer? _tickTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  void _syncTimer() {
    final ctrl = AppScope.of(context);
    if (ctrl.coreRunning && _tickTimer == null) {
      _tickTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!ctrl.coreRunning && _tickTimer != null) {
      _tickTimer!.cancel();
      _tickTimer = null;
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _onToggle() async {
    final ctrl = AppScope.of(context);
    if (ctrl.coreConnecting) return;

    final error = await ctrl.toggleConnection();
    _syncTimer();

    if (mounted && error != null) {
      AppToast.show(context, error, type: AppToastType.error);
    } else if (mounted && ctrl.coreRunning) {
      AppToast.show(context, '连接成功', type: AppToastType.success);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final connected = ctrl.coreRunning;
    final connecting = ctrl.coreConnecting;
    final elapsed = _formatDuration(ctrl.connectedDuration);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Litchi Client',
            subtitle: '现代化跨平台网络加速客户端',
            prominent: true,
          ),
          const SizedBox(height: 12),
          _ConnectionHeroCard(
            connected: connected,
            connecting: connecting,
            elapsedLabel: elapsed,
            onToggle: _onToggle,
          ),
          const SizedBox(height: 14),
          const _InfoMiniCardsRow(),
          const SizedBox(height: 14),
          _StatusBar(connected: connected),
        ],
      ),
    );
  }
}

class _ConnectionHeroCard extends StatelessWidget {
  const _ConnectionHeroCard({
    required this.connected,
    required this.connecting,
    required this.elapsedLabel,
    required this.onToggle,
  });

  final bool connected;
  final bool connecting;
  final String elapsedLabel;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final node = ctrl.currentNode;
    final user = ctrl.user;
    final nodeLabel = ctrl.autoSelected ? '智能推荐节点' : '当前节点';

    return AppCard(
      radius: AppRadius.xl,
      height: 240,
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '欢迎回来，',
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textPrimary,
                          fontSize: 23,
                        ),
                      ),
                      TextSpan(
                        text: user.name,
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.primary,
                          fontSize: 23,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Premium Plan · 到期 ${user.expiry}',
                  style: AppTextStyles.body.copyWith(
                    color: c.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Text(
                  nodeLabel,
                  style: AppTextStyles.body.copyWith(
                    color: c.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CountryFlag.fromCountryCode(
                      node.code.isNotEmpty ? node.code : 'UN',
                      theme: const ImageTheme(
                        width: 28,
                        height: 20,
                        shape: RoundedRectangle(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        node.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    if (node.latency > 0 && node.latency < 9999)
                      AppBadge(
                        text: '${node.latency} ms',
                        background: c.success.withValues(alpha: 0.12),
                        textColor: c.success,
                        fontSize: 13,
                        height: 28,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _HeroActionButton(
                      icon: LucideIcons.refreshCw,
                      label: '切换节点',
                      onTap: () => ctrl.goToPage(AppPage.nodes),
                    ),
                    _HeroActionButton(
                      icon: LucideIcons.crown,
                      label: '续费套餐',
                      onTap: () => ctrl.goToPage(AppPage.shop),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Container(width: 1, color: c.softBorder),
          ),
          const SizedBox(width: 20),
          Expanded(
            flex: 10,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PowerButton(
                  connected: connected,
                  connecting: connecting,
                  onTap: onToggle,
                ),
                const SizedBox(height: 14),
                Text(
                  connecting
                      ? (connected ? '断开中…' : '连接中…')
                      : (connected ? '已连接' : '未连接'),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  connected ? elapsedLabel : '点击连接',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.connected,
    required this.connecting,
    required this.onTap,
  });

  final bool connected;
  final bool connecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: connecting ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: connecting ? null : onTap,
        child: SizedBox(
          width: 128,
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? c.primarySoft.withValues(alpha: 0.7)
                      : c.surfaceMuted.withValues(alpha: 0.65),
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: connected && !connecting
                      ? AppPalette.brandGradient
                      : null,
                  color: connecting
                      ? c.surfaceMuted
                      : (connected ? null : c.surfaceMuted),
                  border: Border.all(
                    color: connected
                        ? Colors.white.withValues(alpha: 0.82)
                        : c.softBorder,
                    width: 2,
                  ),
                  boxShadow: connected && !connecting
                      ? AppShadows.powerButton
                      : null,
                ),
                child: connecting
                    ? Padding(
                        padding: const EdgeInsets.all(34),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: c.primary,
                        ),
                      )
                    : Icon(
                        LucideIcons.power,
                        size: 46,
                        color: connected ? Colors.white : c.iconMuted,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.button.copyWith(
                  color: c.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoMiniCardsRow extends StatelessWidget {
  const _InfoMiniCardsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 560;
        final traffic = _TrafficMiniCard();
        final plan = _PlanMiniCard();
        if (twoCols) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: traffic),
                const SizedBox(width: 24),
                Expanded(child: plan),
              ],
            ),
          );
        }
        return Column(children: [traffic, const SizedBox(height: 16), plan]);
      },
    );
  }
}

class _TrafficMiniCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppScope.of(context).traffic;
    final ratio = (t.usedGb / t.totalGb).clamp(0.0, 1.0);

    return AppCard(
      radius: AppRadius.card,
      height: 120,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _DashboardIconBox(
            icon: LucideIcons.wifi,
            color: c.primary,
            background: c.primarySoft,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '本月流量',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${t.usedGb.toInt()}',
                        style: AppTextStyles.largeNumber(
                          fontSize: 23,
                        ).copyWith(color: c.primary),
                      ),
                      TextSpan(
                        text: ' / ${t.totalGb.toInt()} GB',
                        style: AppTextStyles.bodyStrong.copyWith(
                          color: c.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '剩余 ${t.remainGb.toInt()} GB',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(height: 8, color: c.surfaceMuted),
                      FractionallySizedBox(
                        widthFactor: ratio,
                        child: Container(
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: AppPalette.brandGradient,
                          ),
                        ),
                      ),
                    ],
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

class _PlanMiniCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);
    final user = controller.user;

    return AppCard(
      radius: AppRadius.card,
      height: 120,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _DashboardIconBox(
            icon: LucideIcons.crown,
            color: c.secondary,
            background: c.secondarySoft,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '当前套餐',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.plan,
                  style: AppTextStyles.largeNumber(
                    fontSize: 22,
                  ).copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  '到期时间：${user.expiry}',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppSecondaryButton(
            label: '续费',
            height: 34,
            radius: AppRadius.md,
            onPressed: () => controller.goToPage(AppPage.shop),
          ),
        ],
      ),
    );
  }
}

class _DashboardIconBox extends StatelessWidget {
  const _DashboardIconBox({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, size: 24, color: color),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: [
          _DashboardIconBox(
            icon: connected ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            color: connected ? c.primary : c.iconMuted,
            background: connected ? c.primarySoft : c.surfaceMuted,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Litchi Client 已为您保护网络连接' : '当前未连接，点击电源按钮开始连接',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  connected ? '安全、稳定、纯净的网络体验' : '开启后将自动应用当前节点代理',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, size: 22, color: c.iconMuted),
        ],
      ),
    );
  }
}

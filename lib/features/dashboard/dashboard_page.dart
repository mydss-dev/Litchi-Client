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
          const Duration(seconds: 1), (_) => setState(() {}));
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
          const PageHeader(title: 'Litchi Client', subtitle: '现代化跨平台网络加速客户端'),
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

    return AppCard(
      radius: AppRadius.xl,
      height: 250,
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('欢迎回来，${user.name}',
                    style: AppTextStyles.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                Text('Premium Plan · 到期 ${user.expiry}',
                    style: AppTextStyles.body.copyWith(color: c.textMuted)),
                const Spacer(),
                // Node label row: "智能推荐" badge when auto, plain label otherwise
                if (ctrl.autoSelected)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.zap, size: 11, color: c.primary),
                            const SizedBox(width: 4),
                            Text('智能推荐',
                                style: AppTextStyles.badge.copyWith(
                                    color: c.primary, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('最优节点',
                          style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                    ],
                  )
                else
                  Text('当前节点',
                      style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CountryFlag.fromCountryCode(
                      node.code.isNotEmpty ? node.code : 'UN',
                      theme: const ImageTheme(
                        width: 28, height: 20, shape: RoundedRectangle(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(node.name,
                        style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
                    const SizedBox(width: 12),
                    if (node.latency > 0 && node.latency < 9999)
                      AppBadge.latency(context, text: '${node.latency} ms'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PowerButton(
                    connected: connected,
                    connecting: connecting,
                    onTap: onToggle),
                const SizedBox(height: 18),
                Text(
                  connecting
                      ? (connected ? '断开中…' : '连接中…')
                      : (connected ? '已连接' : '未连接'),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
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
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: connected && !connecting ? AppPalette.brandGradient : null,
            color: connecting
                ? c.surfaceMuted
                : (connected ? null : c.surfaceMuted),
            boxShadow: connected && !connecting ? AppShadows.powerButton : null,
          ),
          child: connecting
              ? Padding(
                  padding: const EdgeInsets.all(30),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: c.primary,
                  ),
                )
              : Icon(
                  LucideIcons.power,
                  size: 40,
                  color: connected ? Colors.white : c.iconMuted,
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
                const SizedBox(width: 14),
                Expanded(child: plan),
              ],
            ),
          );
        }
        return Column(children: [traffic, const SizedBox(height: 14), plan]);
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wifi, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text('本月流量',
                  style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text('${t.usedGb.toInt()} / ${t.totalGb.toInt()} GB',
              style: AppTextStyles.largeNumber(fontSize: 20).copyWith(color: c.textPrimary)),
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
                    decoration: const BoxDecoration(gradient: AppPalette.brandGradient),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('剩余 ${t.remainGb.toInt()} GB',
              style: AppTextStyles.caption.copyWith(color: c.textMuted)),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.crown, size: 16, color: c.warning),
              const SizedBox(width: 8),
              Text('当前套餐',
                  style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Text(user.plan,
              style: AppTextStyles.largeNumber(fontSize: 20).copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('到期时间：${user.expiry}',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ),
              AppSecondaryButton(
                label: '续费',
                height: 30,
                onPressed: () => controller.goToPage(AppPage.shop),
              ),
            ],
          ),
        ],
      ),
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
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: connected ? c.primarySoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              connected ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              size: 18,
              color: connected ? c.primary : c.iconMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connected ? 'Litchi Client 已为您保护网络连接' : '当前未连接，点击电源按钮开始连接',
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
          ),
          AppBadge(
            text: connected ? '安全' : '未保护',
            background: connected
                ? c.success.withValues(alpha: 0.12)
                : c.danger.withValues(alpha: 0.12),
            textColor: connected ? c.success : c.danger,
            fontSize: 11,
            height: 22,
          ),
        ],
      ),
    );
  }
}

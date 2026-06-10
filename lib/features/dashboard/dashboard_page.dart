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
          const PageHeader(title: 'Litchi Client', subtitle: '现代化跨平台网络加速客户端'),
          const SizedBox(height: 12),
          _ConnectionHeroCard(
            connected: connected,
            connecting: connecting,
            elapsedLabel: elapsed,
            onToggle: _onToggle,
          ),
          const SizedBox(height: 12),
          const _InfoMiniCardsRow(),
          const SizedBox(height: 12),
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
      height: 252,
      padding: const EdgeInsets.fromLTRB(24, 24, 22, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeTitle(name: user.name),
                const SizedBox(height: 8),
                Text(
                  'Premium Plan · 到期 ${user.expiry}',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                ),
                const Spacer(),
                Row(
                  children: [
                    _SoftPill(
                      icon: ctrl.autoSelected
                          ? LucideIcons.sparkles
                          : LucideIcons.radio,
                      text: ctrl.autoSelected ? '智能推荐' : '当前节点',
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ctrl.autoSelected ? '最优节点' : '手动选择',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (node.latency > 0 && node.latency < 9999)
                      AppBadge.latency(context, text: '${node.latency} ms'),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _HeroActionButton(
                        icon: LucideIcons.refreshCw,
                        label: '切换节点',
                        onTap: () => ctrl.goToPage(AppPage.nodes),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroActionButton(
                        icon: LucideIcons.gem,
                        label: '续费套餐',
                        onTap: () => ctrl.goToPage(AppPage.shop),
                        accent: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            color: c.softBorder,
          ),
          SizedBox(
            width: 178,
            child: Column(
              children: [
                const Spacer(),
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
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  connected ? elapsedLabel : '点击连接',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const Spacer(),
                _ProxyModeSegment(
                  value: ctrl.proxyMode,
                  onChanged: (mode) {
                    final changed = mode != ctrl.proxyMode;
                    ctrl.setProxyMode(mode);
                    if (changed && ctrl.coreRunning) {
                      AppToast.show(context, '代理模式将在下次连接后生效');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProxyModeSegment extends StatelessWidget {
  const _ProxyModeSegment({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = [
    _ProxyModeItem(label: '规则', value: '智能模式'),
    _ProxyModeItem(label: '全局', value: '全局模式'),
    _ProxyModeItem(label: '直连', value: '直连模式'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selectedValue = _items.any((item) => item.value == value)
        ? value
        : _items.first.value;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _ProxyModeOption(
                item: item,
                selected: item.value == selectedValue,
                onTap: () => onChanged(item.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProxyModeOption extends StatelessWidget {
  const _ProxyModeOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ProxyModeItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button.copyWith(
              color: selected ? c.primary : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProxyModeItem {
  const _ProxyModeItem({required this.label, required this.value});

  final String label;
  final String value;
}

class _WelcomeTitle extends StatelessWidget {
  const _WelcomeTitle({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTextStyles.heroTitle.copyWith(color: c.textPrimary),
        children: [
          const TextSpan(text: '欢迎回来，'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppPalette.brandGradient.createShader(bounds),
              child: Text(
                name,
                style: AppTextStyles.heroTitle.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.badge.copyWith(
              color: c.primary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = accent ? c.secondary : c.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: accent ? c.secondarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: accent ? 0.18 : 0.24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
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
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: connected && !connecting
                ? AppPalette.brandGradient
                : null,
            color: connecting
                ? c.surfaceMuted
                : (connected ? null : c.surfaceMuted),
            boxShadow: connected && !connecting ? AppShadows.powerButton : null,
          ),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: connected
                    ? Colors.white.withValues(alpha: 0.72)
                    : c.cardBg.withValues(alpha: 0.72),
                width: 3,
              ),
            ),
            child: connecting
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: c.primary,
                    ),
                  )
                : Icon(
                    LucideIcons.power,
                    size: 36,
                    color: connected ? Colors.white : c.iconMuted,
                  ),
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
        final twoCols = constraints.maxWidth >= 380;
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricIcon(icon: LucideIcons.wifi, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月流量',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t.usedGb.toInt()} / ${t.totalGb.toInt()} GB',
                      style: AppTextStyles.largeNumber(
                        fontSize: 20,
                      ).copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '剩余 ${t.remainGb.toInt()} GB',
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 7, color: c.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 7,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetricIcon(icon: LucideIcons.crown, color: c.warning),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前套餐',
                      style: AppTextStyles.cardTitle.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.plan,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.largeNumber(
                        fontSize: 20,
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
              const SizedBox(width: 10),
              Align(
                alignment: Alignment.centerRight,
                child: AppSecondaryButton(
                  label: '续费',
                  height: 30,
                  onPressed: () => controller.goToPage(AppPage.shop),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
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
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: connected ? c.primarySoft : c.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              connected ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              size: 21,
              color: connected ? c.primary : c.iconMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Litchi Client 已为您保护网络连接' : '当前未连接，点击电源按钮开始连接',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  connected ? '安全、稳定、纯净的网络体验' : '连接后将自动启用系统代理',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppBadge(
            text: connected ? '安全' : '未保护',
            background: connected
                ? c.success.withValues(alpha: 0.12)
                : c.danger.withValues(alpha: 0.12),
            textColor: connected ? c.success : c.danger,
            fontSize: 11,
            height: 22,
          ),
          const SizedBox(width: 10),
          Icon(LucideIcons.chevronRight, size: 18, color: c.iconMuted),
        ],
      ),
    );
  }
}

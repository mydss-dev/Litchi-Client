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
          const PageHeader(title: '首页', subtitle: '查看当前连接、节点与流量状态'),
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
          const _ConnectionStatsRow(),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '当前节点',
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textPrimary,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    _NodeInlineAction(
                      onTap: () => ctrl.goToPage(AppPage.nodes),
                    ),
                  ],
                ),
                const Spacer(),
                _ConnectionStateLabel(connected: connected),
                const SizedBox(height: 20),
                Row(
                  children: [
                    CountryFlag.fromCountryCode(
                      node.code.isNotEmpty ? node.code : 'UN',
                      theme: const ImageTheme(
                        width: 36,
                        height: 26,
                        shape: RoundedRectangle(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        node.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _NodeMetaRow(
                  proxyMode: ctrl.proxyMode,
                  automatic: ctrl.autoSelected,
                ),
                const Spacer(),
              ],
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            color: c.softBorder,
          ),
          Expanded(
            child: Column(
              children: [
                const Spacer(),
                _PowerButton(
                  connected: connected,
                  connecting: connecting,
                  onTap: onToggle,
                ),
                const SizedBox(height: 14),
                _ConnectionActionText(
                  connected: connected,
                  connecting: connecting,
                ),
                if (connected) ...[
                  const SizedBox(height: 6),
                  Text(
                    elapsedLabel,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeMiniCard extends StatelessWidget {
  const _ModeMiniCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '代理模式',
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_proxyModeLabel(ctrl.proxyMode)} · ${ctrl.coreRunning ? '系统代理已开启' : '系统代理未开启'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
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
    );
  }

  String _proxyModeLabel(String mode) {
    return switch (mode) {
      '全局模式' => '全局模式',
      '直连模式' => '直连模式',
      _ => '规则模式',
    };
  }
}

class _ProxyModeSegment extends StatelessWidget {
  const _ProxyModeSegment({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = [
    _ProxyModeItem(label: '规则', value: '规则模式'),
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

class _ConnectionStateLabel extends StatelessWidget {
  const _ConnectionStateLabel({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = connected ? c.success : c.textMuted;
    return Container(
      height: 24,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? '已连接' : '未连接',
            style: AppTextStyles.button.copyWith(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeMetaRow extends StatelessWidget {
  const _NodeMetaRow({required this.proxyMode, required this.automatic});

  final String proxyMode;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Text(
      '${_proxyModeLabel(proxyMode)} · ${automatic ? '自动选择' : '手动选择'}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(
        color: c.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _proxyModeLabel(String mode) {
    return switch (mode) {
      '全局模式' => '全局模式',
      '直连模式' => '直连模式',
      _ => '规则模式',
    };
  }
}

class _NodeInlineAction extends StatelessWidget {
  const _NodeInlineAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.refreshCw, size: 13, color: c.primary),
              const SizedBox(width: 6),
              Text(
                '切换节点',
                style: AppTextStyles.button.copyWith(
                  color: c.primary,
                  fontSize: 11,
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
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: connected && !connecting
                ? AppPalette.brandGradient
                : null,
            color: connecting
                ? c.surfaceMuted
                : (connected ? null : c.surfaceMuted),
            border: connected || connecting
                ? null
                : Border.all(color: c.primary.withValues(alpha: 0.14)),
            boxShadow: connected && !connecting
                ? AppShadows.powerButton
                : [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Container(
            margin: const EdgeInsets.all(7),
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
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: c.primary,
                    ),
                  )
                : Icon(
                    LucideIcons.power,
                    size: 44,
                    color: connected ? Colors.white : c.primary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionActionText extends StatelessWidget {
  const _ConnectionActionText({
    required this.connected,
    required this.connecting,
  });

  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = connecting
        ? (connected ? '断开中…' : '连接中…')
        : (connected ? '断开连接' : '开始连接');
    final color = connecting ? c.primary : (connected ? c.success : c.primary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTextStyles.sectionTitle.copyWith(
            color: color,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatsRow extends StatelessWidget {
  const _ConnectionStatsRow();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final connected = ctrl.coreRunning;
    final latency = ctrl.currentNode.latency;
    final latencyValue = latency > 0 && latency < 9999
        ? latency.toString()
        : '--';

    return LayoutBuilder(
      builder: (context, constraints) {
        final threeCols = constraints.maxWidth >= 560;
        final cards = [
          _ConnectionStatCard(label: '当前延迟', value: latencyValue, unit: 'ms'),
          _ConnectionStatCard(
            label: '下载速度',
            value: connected ? '12.8' : '--',
            unit: connected ? 'MB/s' : '',
          ),
          _ConnectionStatCard(
            label: '上传速度',
            value: connected ? '2.1' : '--',
            unit: connected ? 'MB/s' : '',
          ),
        ];

        if (threeCols) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }

        return Column(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              cards[i],
            ],
          ],
        );
      },
    );
  }
}

class _ConnectionStatCard extends StatelessWidget {
  const _ConnectionStatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: c.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: AppTextStyles.largeNumber(
                  fontSize: 24,
                ).copyWith(color: c.textPrimary, height: 1),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontSize: 11,
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

class _InfoMiniCardsRow extends StatelessWidget {
  const _InfoMiniCardsRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth >= 380;
        final mode = const _ModeMiniCard();
        final network = const _NetworkSettingsCard();
        if (twoCols) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: mode),
                const SizedBox(width: 14),
                Expanded(child: network),
              ],
            ),
          );
        }
        return Column(children: [mode, const SizedBox(height: 14), network]);
      },
    );
  }
}

class _NetworkSettingsCard extends StatefulWidget {
  const _NetworkSettingsCard();

  @override
  State<_NetworkSettingsCard> createState() => _NetworkSettingsCardState();
}

class _NetworkSettingsCardState extends State<_NetworkSettingsCard> {
  String _mode = 'system';

  void _setMode(String mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == 'tun') {
      AppToast.show(context, '虚拟网卡模式暂未接入，将在后续版本启用');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '网络设置',
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _mode == 'system' ? '使用系统代理接管网络请求' : '通过虚拟网卡接管全部流量',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NetworkModeOption(
                    label: '系统代理',
                    selected: _mode == 'system',
                    onTap: () => _setMode('system'),
                  ),
                ),
                Expanded(
                  child: _NetworkModeOption(
                    label: '虚拟网卡',
                    selected: _mode == 'tun',
                    onTap: () => _setMode('tun'),
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

class _NetworkModeOption extends StatelessWidget {
  const _NetworkModeOption({
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
            label,
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

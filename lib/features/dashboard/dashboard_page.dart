import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart' show ConnectionStatus;
import '../../shared/models/app_models.dart' show UserModel;
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
    final status = ctrl.connectionStatus;
    final elapsed = _formatDuration(ctrl.connectedDuration);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '首页', subtitle: '查看当前连接、节点与流量状态'),
          const SizedBox(height: 12),
          _ExpiryBanner(user: ctrl.user),
          _ConnectionHeroCard(
            status: status,
            elapsedLabel: elapsed,
            onToggle: _onToggle,
          ),
          if (status == ConnectionStatus.error && ctrl.coreError.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ErrorBanner(message: ctrl.coreError, onRetry: _onToggle),
          ],
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
    required this.status,
    required this.elapsedLabel,
    required this.onToggle,
  });

  final ConnectionStatus status;
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
                _ConnectionStateLabel(status: status),
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
                  status: status,
                  onTap: onToggle,
                ),
                const SizedBox(height: 14),
                _ConnectionActionText(status: status),
                if (status == ConnectionStatus.connected) ...[
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
              if (mode == ctrl.proxyMode) return;
              final wasRunning = ctrl.coreRunning;
              ctrl.setProxyMode(mode); // saves pref + fires Clash API if running
              if (wasRunning) {
                AppToast.show(
                  context,
                  '已切换至 ${_proxyModeLabel(mode)}',
                  type: AppToastType.success,
                );
              } else {
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
  const _ConnectionStateLabel({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('已连接', c.success),
      ConnectionStatus.connecting => ('连接中', c.primary),
      ConnectionStatus.disconnecting => ('断开中', c.textMuted),
      ConnectionStatus.error => ('连接失败', c.danger),
      ConnectionStatus.disconnected => ('未连接', c.textMuted),
    };
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
            label,
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
  const _PowerButton({required this.status, required this.onTap});

  final ConnectionStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isConnected = status == ConnectionStatus.connected;
    final isTransitioning = status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;

    return MouseRegion(
      cursor: isTransitioning ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isTransitioning ? null : onTap,
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isConnected ? AppPalette.brandGradient : null,
            color: isTransitioning
                ? c.surfaceMuted
                : (isConnected ? null : c.surfaceMuted),
            border: isConnected || isTransitioning
                ? null
                : Border.all(color: c.primary.withValues(alpha: 0.14)),
            boxShadow: isConnected
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
                color: isConnected
                    ? Colors.white.withValues(alpha: 0.72)
                    : c.cardBg.withValues(alpha: 0.72),
                width: 3,
              ),
            ),
            child: isTransitioning
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
                    color: isConnected ? Colors.white : c.primary,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionActionText extends StatelessWidget {
  const _ConnectionActionText({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (text, color) = switch (status) {
      ConnectionStatus.disconnected => ('开始连接', c.primary),
      ConnectionStatus.connecting => ('连接中…', c.primary),
      ConnectionStatus.connected => ('断开连接', c.success),
      ConnectionStatus.disconnecting => ('断开中…', c.textMuted),
      ConnectionStatus.error => ('重新连接', c.danger),
    };

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

class _ExpiryBanner extends StatelessWidget {
  const _ExpiryBanner({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    if (user.expiry.isEmpty) return const SizedBox.shrink();
    final expiry = DateTime.tryParse(user.expiry);
    if (expiry == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = expiryDay.difference(today).inDays;

    if (daysLeft > 7) return const SizedBox.shrink();

    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final color = daysLeft <= 0 ? c.danger : c.warning;
    final message = daysLeft < 0
        ? '订阅已过期，连接将无法使用'
        : daysLeft == 0
            ? '订阅今日到期，请及时续费'
            : '订阅将在 $daysLeft 天后到期';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => ctrl.goToPage(AppPage.shop),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 16, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: AppTextStyles.body.copyWith(
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '去续费 →',
                  style: AppTextStyles.button.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, size: 16, color: c.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: c.danger,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: c.danger.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '重试',
                  style: AppTextStyles.button.copyWith(
                    color: c.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats bytes-per-second into a human-readable (value, unit) pair.
(String, String) _formatSpeed(int bps) {
  if (bps <= 0) return ('--', '');
  if (bps < 1024) return ('$bps', 'B/s');
  if (bps < 1024 * 1024) return ((bps / 1024).toStringAsFixed(1), 'KB/s');
  return ((bps / (1024 * 1024)).toStringAsFixed(1), 'MB/s');
}

class _ConnectionStatsRow extends StatelessWidget {
  const _ConnectionStatsRow();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final latency = ctrl.currentNode.latency;
    final latencyValue = latency > 0 && latency < 9999
        ? latency.toString()
        : '--';
    final (downValue, downUnit) = _formatSpeed(ctrl.downBps);
    final (upValue, upUnit) = _formatSpeed(ctrl.upBps);

    return LayoutBuilder(
      builder: (context, constraints) {
        final threeCols = constraints.maxWidth >= 560;
        final cards = [
          _ConnectionStatCard(label: '当前延迟', value: latencyValue, unit: 'ms'),
          _ConnectionStatCard(label: '下载速度', value: downValue, unit: downUnit),
          _ConnectionStatCard(label: '上传速度', value: upValue, unit: upUnit),
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

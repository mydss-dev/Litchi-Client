import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../app/core_controller.dart' show ConnectionStatus;
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_palette.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import 'desktop_node_picker_dialog.dart';

class ConnectionHeroCard extends StatelessWidget {
  const ConnectionHeroCard({
    super.key,
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
    final hasNode = node.name.isNotEmpty;

    return AppCard(
      radius: AppRadius.xl,
      height: 228,
      padding: const EdgeInsets.fromLTRB(22, 22, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasNode ? '当前节点' : '节点状态',
                        style: AppTextStyles.heroTitle.copyWith(
                          color: c.textPrimary,
                          fontSize: 21,
                        ),
                      ),
                    ),
                    _NodeInlineAction(
                      hasNodes: ctrl.nodes.isNotEmpty,
                      onTap: () => showDesktopNodePicker(context),
                    ),
                  ],
                ),
                const Spacer(),
                _ConnectionStateLabel(status: status),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroNodeIcon(node: node),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasNode ? node.name : '暂无可用节点',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.heroTitle.copyWith(
                              color: c.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (!hasNode) ...[
                            const SizedBox(height: 4),
                            Text(
                              '登录后会自动拉取订阅节点',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                color: c.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _NodeMetaRow(
                  node: node,
                  proxyMode: ctrl.proxyMode,
                  automatic: ctrl.autoSelected,
                ),
                const Spacer(),
              ],
            ),
          ),
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            color: c.softBorder,
          ),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                const Spacer(),
                _PowerButton(status: status, onTap: onToggle),
                const SizedBox(height: 12),
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

class _HeroNodeIcon extends StatelessWidget {
  const _HeroNodeIcon({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (node.code.isNotEmpty) {
      return CountryFlag.fromCountryCode(
        node.code,
        theme: const ImageTheme(
          width: 36,
          height: 26,
          shape: RoundedRectangle(4),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(LucideIcons.globe2, size: 19, color: c.primary),
    );
  }
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
  const _NodeMetaRow({
    required this.node,
    required this.proxyMode,
    required this.automatic,
  });

  final NodeModel node;
  final ProxyMode proxyMode;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final latency = switch (node.latency) {
      -1 => '测速中',
      > 0 && < 9999 => '${node.latency} ms',
      >= 9999 => '超时',
      _ => '未测速',
    };
    return Text(
      '${proxyMode.label} · ${automatic ? '自动选择' : '手动选择'} · $latency',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(
        color: c.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _NodeInlineAction extends StatelessWidget {
  const _NodeInlineAction({required this.hasNodes, required this.onTap});

  final bool hasNodes;
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.chevronsUpDown, size: 14, color: c.primary),
              const SizedBox(width: 6),
              Text(
                hasNodes ? '切换节点' : '查看节点',
                style: AppTextStyles.button.copyWith(
                  color: c.primary,
                  fontSize: 12,
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
    final isTransitioning =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;

    return MouseRegion(
      cursor: isTransitioning ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isTransitioning ? null : onTap,
        child: Container(
          width: 104,
          height: 104,
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
            margin: const EdgeInsets.all(6),
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
                    padding: const EdgeInsets.all(28),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: c.primary,
                    ),
                  )
                : Icon(
                    LucideIcons.power,
                    size: 40,
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

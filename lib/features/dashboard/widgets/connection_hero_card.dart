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

/// Vertical "connect hero" — the connection is the focal point: a status pill,
/// a large power button, the action label, then a tappable node row. Mirrors the
/// mobile home layout (the established VPN-client pattern).
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

    return AppCard(
      radius: AppRadius.xl,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Column(
        children: [
          _StatusPill(status: status),
          const SizedBox(height: 22),
          _PowerButton(status: status, onTap: onToggle),
          const SizedBox(height: 16),
          _ConnectionActionText(status: status),
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: status == ConnectionStatus.connected
                ? Text(
                    elapsedLabel,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          _NodeSelectorRow(
            node: node,
            proxyMode: ctrl.proxyMode,
            automatic: ctrl.autoSelected,
            hasNodes: ctrl.nodes.isNotEmpty,
            onTap: () => showDesktopNodePicker(context),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (label, color) = switch (status) {
      ConnectionStatus.connected => ('保护中', c.success),
      ConnectionStatus.connecting => ('连接中', c.primary),
      ConnectionStatus.disconnecting => ('断开中', c.textMuted),
      ConnectionStatus.error => ('连接失败', c.danger),
      ConnectionStatus.disconnected => ('未连接', c.textMuted),
    };
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
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

class _NodeSelectorRow extends StatefulWidget {
  const _NodeSelectorRow({
    required this.node,
    required this.proxyMode,
    required this.automatic,
    required this.hasNodes,
    required this.onTap,
  });

  final NodeModel node;
  final ProxyMode proxyMode;
  final bool automatic;
  final bool hasNodes;
  final VoidCallback onTap;

  @override
  State<_NodeSelectorRow> createState() => _NodeSelectorRowState();
}

class _NodeSelectorRowState extends State<_NodeSelectorRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final node = widget.node;
    final hasNode = node.name.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hover ? c.primarySoft.withValues(alpha: 0.5) : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: c.softBorder),
          ),
          child: Row(
            children: [
              _HeroNodeIcon(node: node),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasNode ? node.name : '请选择节点',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _NodeMetaRow(
                      node: node,
                      proxyMode: widget.proxyMode,
                      automatic: widget.automatic,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.hasNodes ? '切换' : '查看',
                style: AppTextStyles.button.copyWith(
                  color: c.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: c.iconMuted),
            ],
          ),
        ),
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
          width: 40,
          height: 30,
          shape: RoundedRectangle(6),
        ),
      );
    }
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Icon(LucideIcons.globe2, size: 20, color: c.primary),
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
      '${automatic ? '自动选择' : '手动选择'} · $latency',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.caption.copyWith(color: c.textMuted),
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
          width: 128,
          height: 128,
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
                    padding: const EdgeInsets.all(34),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: c.primary,
                    ),
                  )
                : Icon(
                    LucideIcons.power,
                    size: 48,
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

    return Text(
      text,
      style: AppTextStyles.sectionTitle.copyWith(color: color, fontSize: 20),
    );
  }
}

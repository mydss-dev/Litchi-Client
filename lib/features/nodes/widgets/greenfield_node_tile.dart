import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/node_latency.dart';

class GreenfieldNodeTile extends StatefulWidget {
  const GreenfieldNodeTile({
    super.key,
    required this.node,
    required this.selected,
    required this.favorite,
    required this.compact,
    required this.onPressed,
    this.onToggleFavorite,
    this.pinnedCurrent = false,
  });

  static const double desktopHeight = 62;
  static const double compactHeight = 76;

  final NodeModel node;
  final bool selected;
  final bool favorite;
  final bool compact;
  final VoidCallback onPressed;
  final VoidCallback? onToggleFavorite;
  final bool pinnedCurrent;

  @override
  State<GreenfieldNodeTile> createState() => _GreenfieldNodeTileState();
}

class _GreenfieldNodeTileState extends State<GreenfieldNodeTile> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final emphasized = widget.selected || _hovered || _focused;
    final metadata = _metadata(widget.node);
    final rowHeight = widget.compact
        ? GreenfieldNodeTile.compactHeight
        : GreenfieldNodeTile.desktopHeight;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) {
        if (_hovered == value) return;
        setState(() => _hovered = value);
      },
      onShowFocusHighlight: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOutCubic,
        height: rowHeight,
        decoration: BoxDecoration(
          color: widget.selected
              ? c.primarySoft
              : emphasized
              ? c.surfaceMuted
              : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: widget.selected
                ? c.primary.withValues(alpha: 0.34)
                : _focused
                ? c.primary.withValues(alpha: 0.26)
                : c.softBorder,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 3,
                  height: widget.selected ? rowHeight - 22 : 0,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2),
                    ),
                  ),
                ),
                SizedBox(width: widget.compact ? AppSpacing.md : AppSpacing.lg),
                _NodeFlag(node: widget.node, compact: widget.compact),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.node.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: widget.selected
                                    ? c.primary
                                    : c.textPrimary,
                              ),
                            ),
                          ),
                          if (widget.pinnedCurrent) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _CurrentBadge(label: context.l10n.currentNode),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                NodeLatency(
                  latency: widget.node.latency,
                  style: NodeLatencyStyle.badge,
                ),
                if (widget.onToggleFavorite != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppIconButton(
                    icon: LucideIcons.star,
                    onPressed: widget.onToggleFavorite,
                    tooltip: context.l10n.favorites,
                    compact: !widget.compact,
                    variant: widget.favorite
                        ? AppIconButtonVariant.primary
                        : AppIconButtonVariant.ghost,
                  ),
                ],
                SizedBox(width: widget.compact ? AppSpacing.sm : AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _metadata(NodeModel node) {
    final values = <String>[];
    if (node.englishName.trim().isNotEmpty) values.add(node.englishName.trim());
    for (final tag in node.tags.take(2)) {
      final value = tag.trim();
      if (value.isNotEmpty && !values.contains(value)) values.add(value);
    }
    if (values.isEmpty && node.code.isNotEmpty) values.add(node.code);
    return values.isEmpty ? 'Litchi' : values.join(' · ');
  }
}

class _NodeFlag extends StatelessWidget {
  const _NodeFlag({required this.node, required this.compact});

  final NodeModel node;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final size = compact ? 42.0 : 38.0;
    final code = node.code.isEmpty ? 'UN' : node.code;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: CountryFlag.fromCountryCode(
        code,
        theme: const ImageTheme(
          width: 26,
          height: 18,
          shape: RoundedRectangle(3),
        ),
      ),
    );
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppTextStyles.caption.copyWith(
          color: c.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

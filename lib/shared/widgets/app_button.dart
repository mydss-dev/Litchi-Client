import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppControlSize.regular,
    this.leadingIcon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppControlSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool loading;
  final bool expand;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null && !loading;
    final height = size == AppControlSize.compact
        ? AppControlMetrics.compactHeight
        : AppControlMetrics.regularHeight;
    final iconSize = size == AppControlSize.compact
        ? AppControlMetrics.compactIconSize
        : AppControlMetrics.regularIconSize;
    final labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final button = TextButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        animationDuration: AppMotion.fast,
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: size == AppControlSize.compact
                ? AppSpacing.md
                : AppSpacing.lg,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => _background(c, states),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => _foreground(c, states),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => _overlay(c, states),
        ),
        side: WidgetStateProperty.resolveWith((states) => _side(c, states)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
        mouseCursor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            SizedBox(
              width: iconSize,
              height: iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _baseForeground(c, enabled: true),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (leadingIcon != null) ...[
            Icon(leadingIcon, size: iconSize),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (expand) Expanded(child: labelWidget) else labelWidget,
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(trailingIcon, size: iconSize),
          ],
        ],
      ),
    );

    final sized = expand ? SizedBox(width: double.infinity, child: button) : button;
    if (tooltip == null || tooltip!.isEmpty) return sized;
    return Tooltip(message: tooltip!, child: sized);
  }

  Color _baseForeground(AppColors c, {required bool enabled}) {
    if (!enabled) return c.textMuted;
    return switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => Colors.white,
      AppButtonVariant.secondary || AppButtonVariant.outline => c.textPrimary,
      AppButtonVariant.ghost => c.textSecondary,
    };
  }

  Color _foreground(AppColors c, Set<WidgetState> states) => _baseForeground(
    c,
    enabled: !states.contains(WidgetState.disabled),
  );

  Color _background(AppColors c, Set<WidgetState> states) {
    final disabled = states.contains(WidgetState.disabled);
    final hovered = states.contains(WidgetState.hovered);
    final pressed = states.contains(WidgetState.pressed);

    if (disabled) {
      return switch (variant) {
        AppButtonVariant.primary => c.primary.withValues(alpha: 0.34),
        AppButtonVariant.danger => c.danger.withValues(alpha: 0.30),
        AppButtonVariant.secondary => c.surfaceMuted.withValues(alpha: 0.65),
        AppButtonVariant.outline || AppButtonVariant.ghost => Colors.transparent,
      };
    }

    return switch (variant) {
      AppButtonVariant.primary => hovered || pressed ? c.primaryHover : c.primary,
      AppButtonVariant.secondary =>
        hovered || pressed ? c.primarySoft : c.surfaceMuted,
      AppButtonVariant.outline || AppButtonVariant.ghost => Colors.transparent,
      AppButtonVariant.danger => pressed
          ? Color.alphaBlend(Colors.black.withValues(alpha: 0.10), c.danger)
          : hovered
          ? Color.alphaBlend(Colors.black.withValues(alpha: 0.06), c.danger)
          : c.danger,
    };
  }

  Color _overlay(AppColors c, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    final filled =
        variant == AppButtonVariant.primary || variant == AppButtonVariant.danger;
    if (states.contains(WidgetState.pressed)) {
      return filled
          ? Colors.white.withValues(alpha: 0.10)
          : c.primary.withValues(alpha: 0.10);
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return filled
          ? Colors.white.withValues(alpha: 0.05)
          : c.primary.withValues(alpha: 0.055);
    }
    return Colors.transparent;
  }

  BorderSide _side(AppColors c, Set<WidgetState> states) {
    final focused = states.contains(WidgetState.focused);
    final disabled = states.contains(WidgetState.disabled);

    if (focused) {
      final filled =
          variant == AppButtonVariant.primary || variant == AppButtonVariant.danger;
      return BorderSide(
        color: filled
            ? Colors.white.withValues(alpha: 0.72)
            : c.primary.withValues(alpha: 0.72),
        width: 1.5,
      );
    }

    return switch (variant) {
      AppButtonVariant.secondary => BorderSide(
        color: disabled ? c.softBorder.withValues(alpha: 0.6) : c.softBorder,
      ),
      AppButtonVariant.outline => BorderSide(
        color: disabled ? c.border.withValues(alpha: 0.55) : c.border,
      ),
      _ => BorderSide.none,
    };
  }
}

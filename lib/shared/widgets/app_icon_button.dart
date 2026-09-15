import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import '../layout/app_platform.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';

enum AppIconButtonVariant { ghost, surface, primary, danger }

/// Shared icon-only action with pointer/touch adaptive target geometry.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.variant = AppIconButtonVariant.ghost,
    this.compact = false,
    this.iconSize,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final AppIconButtonVariant variant;
  final bool compact;
  final double? iconSize;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final adaptiveExtent = AppControlMetrics.iconButtonExtent;
    final extent = compact &&
            !AppControlMetrics.usesTouchFor(AppPlatform.current)
        ? AppControlMetrics.pointerCompactHeight
        : adaptiveExtent;
    final effectiveIconSize =
        iconSize ??
        (compact
            ? AppControlMetrics.compactIconSize
            : AppControlMetrics.regularIconSize);

    return IconButton(
      onPressed: loading ? null : onPressed,
      tooltip: tooltip,
      icon: loading
          ? SizedBox.square(
              dimension: effectiveIconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.primary,
              ),
            )
          : Icon(icon, size: effectiveIconSize),
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: extent, height: extent),
      style: ButtonStyle(
        animationDuration: AppMotion.fast,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.standard,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => _background(c, states),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => _foreground(c, states),
        ),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => _overlay(c, states),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (!states.contains(WidgetState.focused)) return BorderSide.none;
          return BorderSide(
            color: c.primary.withValues(alpha: 0.68),
            width: 1.5,
          );
        }),
        mouseCursor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
        ),
      ),
    );
  }

  Color _foreground(AppColors c, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return c.iconMuted.withValues(alpha: 0.55);
    }
    return switch (variant) {
      AppIconButtonVariant.primary => c.primary,
      AppIconButtonVariant.danger => c.danger,
      AppIconButtonVariant.ghost ||
      AppIconButtonVariant.surface => c.iconDefault,
    };
  }

  Color _background(AppColors c, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) {
      return variant == AppIconButtonVariant.surface
          ? c.surfaceMuted.withValues(alpha: 0.5)
          : Colors.transparent;
    }
    final active = states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.focused);
    return switch (variant) {
      AppIconButtonVariant.ghost =>
        active ? c.surfaceMuted : Colors.transparent,
      AppIconButtonVariant.surface => active ? c.primarySoft : c.surfaceMuted,
      AppIconButtonVariant.primary =>
        active ? c.primarySoft : Colors.transparent,
      AppIconButtonVariant.danger => active ? c.dangerSoft : Colors.transparent,
    };
  }

  Color _overlay(AppColors c, Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    if (states.contains(WidgetState.pressed)) {
      return variant == AppIconButtonVariant.danger
          ? c.danger.withValues(alpha: 0.10)
          : c.primary.withValues(alpha: 0.10);
    }
    return Colors.transparent;
  }
}

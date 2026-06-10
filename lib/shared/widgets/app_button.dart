import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Filled primary action button (§21 Primary Button).
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 38,
    this.radius = AppRadius.md,
    this.expand = false,
    this.gradient,
    this.icon,
    this.fontSize = 13,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;
  final bool expand;

  /// Optional gradient fill (e.g. the auth main button uses brand gradient).
  final Gradient? gradient;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: AppTextStyles.button.copyWith(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: gradient == null ? c.primary : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Soft secondary button (§21 Secondary Button).
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.height = 34,
    this.radius = AppRadius.sm,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.button.copyWith(color: c.primary),
            ),
          ),
        ),
      ),
    );
  }
}

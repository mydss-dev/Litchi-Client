import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

enum AppCardShadow { none, soft, card }

/// Standard surface card (§21 AppCard): card background, soft border,
/// card shadow, configurable radius and padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadius.card,
    this.width,
    this.height,
    this.color,
    this.shadow = AppCardShadow.card,
    this.border = true,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final double? height;
  final Color? color;
  final AppCardShadow shadow;
  final bool border;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final decoration = BoxDecoration(
      color: color,
      gradient: color == null ? c.cardGradient : null,
      borderRadius: BorderRadius.circular(radius),
      border: border
          ? Border.all(color: borderColor ?? c.softBorder, width: borderWidth)
          : null,
      boxShadow: switch (shadow) {
        AppCardShadow.none => null,
        AppCardShadow.soft => AppShadows.soft(c),
        AppCardShadow.card => AppShadows.card(c),
      },
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          width: width,
          height: height,
          decoration: decoration,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: decoration,
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

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
    this.shadow = true,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final double? height;
  final Color? color;
  final bool shadow;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: c.softBorder) : null,
        boxShadow: shadow ? AppShadows.card(c) : null,
      ),
      child: child,
    );
  }
}

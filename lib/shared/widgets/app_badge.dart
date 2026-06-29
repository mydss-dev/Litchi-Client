import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Pill badge used for Premium tags and latency/status chips (§21).
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.text,
    required this.background,
    required this.textColor,
    this.fontSize = 10,
    this.height = 20,
  });

  final String text;
  final Color background;
  final Color textColor;
  final double fontSize;
  final double height;

  /// Premium plan badge (§21 Premium Badge).
  factory AppBadge.premium(BuildContext context, {String text = 'Premium'}) {
    final c = AppColors.of(context);
    return AppBadge(
      text: text,
      background: c.premiumBadgeBg,
      textColor: c.premiumBadgeText,
      fontSize: 9,
      height: 18,
    );
  }

  /// Green latency badge, e.g. "31 ms" (§10.3).
  factory AppBadge.latency(BuildContext context, {required String text}) {
    final c = AppColors.of(context);
    return AppBadge(
      text: text,
      background: c.success.withValues(alpha: 0.12),
      textColor: c.success,
      fontSize: 12,
      height: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      // widthFactor: 1 shrink-wraps the pill to the text width (so it doesn't
      // stretch to fill loose parents), while still centering vertically.
      child: Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: Text(
          text,
          style: AppTextStyles.badge.copyWith(
            color: textColor,
            fontSize: fontSize,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Unified page header for all main pages (§9): subtitle on top, title below.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.prominent = false,
  });

  final String title;
  final String subtitle;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = prominent ? 72.0 : 54.0;
    final titleStyle = prominent
        ? AppTextStyles.pageTitle.copyWith(
            color: c.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.08,
          )
        : AppTextStyles.pageTitle.copyWith(color: c.textPrimary);
    final subtitleStyle = prominent
        ? AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontSize: 13,
            height: 1.2,
          )
        : AppTextStyles.caption.copyWith(color: c.textMuted);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(subtitle, style: subtitleStyle),
          SizedBox(height: prominent ? 7 : 4),
          Text(title, style: titleStyle),
        ],
      ),
    );
  }
}

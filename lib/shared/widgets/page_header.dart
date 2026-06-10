import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Unified page header for all main pages (§9): title on top, subtitle below.
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
    final height = prominent ? 76.0 : 68.0;
    final titleStyle = prominent
        ? AppTextStyles.pageTitle.copyWith(
            color: c.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.12,
          )
        : AppTextStyles.pageTitle.copyWith(
            color: c.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.12,
          );
    final subtitleStyle = prominent
        ? AppTextStyles.caption.copyWith(
            color: c.textSecondary,
            fontSize: 13,
            height: 1.25,
          )
        : AppTextStyles.body.copyWith(
            color: c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.25,
          );

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(title, style: titleStyle),
          SizedBox(height: prominent ? 8 : 6),
          Text(subtitle, style: subtitleStyle),
        ],
      ),
    );
  }
}

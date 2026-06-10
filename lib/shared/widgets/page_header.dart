import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Unified page header for all main pages (§9): subtitle on top, title below.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 4),
          Text(title, style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}

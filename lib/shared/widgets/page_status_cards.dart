import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

/// Spinner card shown while a page is loading data.
class PageLoadingCard extends StatelessWidget {
  const PageLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
      ),
    );
  }
}

/// Error card with message and a retry button.
class PageErrorCard extends StatelessWidget {
  const PageErrorCard({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(LucideIcons.circleX, size: 32, color: c.danger),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  '重试',
                  style: AppTextStyles.body.copyWith(color: c.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small square refresh icon button shown in page headers.
class RefreshIconButton extends StatelessWidget {
  const RefreshIconButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(LucideIcons.refreshCw, size: 14, color: c.iconDefault),
        ),
      ),
    );
  }
}

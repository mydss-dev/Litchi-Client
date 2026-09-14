import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../services/app_error_message_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_icon_button.dart';

/// Spinner card shown while a page is loading data.
class PageLoadingCard extends StatelessWidget {
  const PageLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.xxxxl),
      child: Center(
        child: CircularProgressIndicator(color: c.primary, strokeWidth: 2),
      ),
    );
  }
}

/// Error card with a consistent shared retry action.
class PageErrorCard extends StatelessWidget {
  const PageErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final displayMessage = AppErrorMessageService.userFacing(
      message,
      context.l10n,
    );

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.circleX, size: 32, color: c.danger),
          const SizedBox(height: AppSpacing.md),
          Text(
            displayMessage,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.retry,
            variant: AppButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Square icon buttons shown in secondary page headers.
class RefreshIconButton extends StatelessWidget {
  const RefreshIconButton({super.key, required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PageIconButton(
      icon: LucideIcons.refreshCw,
      tooltip: tooltip ?? context.l10n.refresh,
      onTap: onTap,
    );
  }
}

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key, required this.onTap, this.tooltip});

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PageIconButton(
      icon: LucideIcons.chevronLeft,
      tooltip: tooltip ?? context.l10n.back,
      onTap: onTap,
    );
  }
}

/// Compatibility wrapper kept for existing feature pages.
///
/// Interaction geometry, hover, focus and disabled feedback now come from
/// [AppIconButton] instead of a second hand-built icon-button implementation.
class PageIconButton extends StatelessWidget {
  const PageIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onTap,
      variant: filled
          ? AppIconButtonVariant.primary
          : AppIconButtonVariant.surface,
    );
  }
}

class PageStateCard extends StatelessWidget {
  const PageStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  static const double _iconExtent = 40;
  static const double _iconSize = 20;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      onTap: onTap,
      shadow: AppCardShadow.none,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: _iconExtent,
            height: _iconExtent,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: c.iconMuted, size: _iconSize),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
          ],
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xxl,
    ),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: c.iconMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

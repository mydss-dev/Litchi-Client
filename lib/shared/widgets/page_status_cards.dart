import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../services/app_error_message_service.dart';
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
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(LucideIcons.circleX, size: 32, color: c.danger),
          const SizedBox(height: 12),
          Text(
            displayMessage,
            style: AppTextStyles.body.copyWith(color: c.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  context.l10n.retry,
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
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip ?? '',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? c.primarySoft : c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: filled ? c.primarySoft : c.softBorder),
            ),
            child: Icon(
              icon,
              size: 18,
              color: filled ? c.primary : c.textPrimary,
            ),
          ),
        ),
      ),
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: c.iconMuted, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 10),
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
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
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
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 4),
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

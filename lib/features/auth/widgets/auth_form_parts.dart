import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_control_metrics.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_motion.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Small reusable pieces shared by the auth forms.

class AuthCheckboxRow extends StatelessWidget {
  const AuthCheckboxRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.child,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: AppControlMetrics.compactHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: value ? c.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(
                      color: value ? c.primary : c.border,
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(
                          LucideIcons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                child ??
                    Text(
                      label,
                      style: AppTextStyles.caption.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline primary action used for forgot-password and auth-screen jumps.
class AuthLinkText extends StatelessWidget {
  const AuthLinkText({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextButton(
      onPressed: onTap,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(0, AppControlMetrics.compactHeight),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        ),
        foregroundColor: WidgetStatePropertyAll(c.primary),
        overlayColor: WidgetStatePropertyAll(
          c.primary.withValues(alpha: 0.08),
        ),
        textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      child: Text(text),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final line = Expanded(child: Divider(color: c.border, height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label ?? context.l10n.or,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

class AuthBottomJump extends StatelessWidget {
  const AuthBottomJump({
    super.key,
    required this.leadingText,
    required this.actionText,
    this.onTap,
  });

  final String leadingText;
  final String actionText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        Text(
          leadingText,
          style: AppTextStyles.caption.copyWith(color: c.textSecondary),
        ),
        AuthLinkText(text: actionText, onTap: onTap),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Compact select / dropdown with consistent desktop hover and focus behavior.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.minWidth = 112,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: PopupMenuButton<T>(
        initialValue: value,
        onSelected: onChanged,
        position: PopupMenuPosition.under,
        color: c.cardBg,
        elevation: 5,
        tooltip: labelOf(value),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.softBorder),
        ),
        itemBuilder: (context) => [
          for (final item in items)
            PopupMenuItem<T>(
              value: item,
              height: 38,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labelOf(item),
                      style: AppTextStyles.body.copyWith(
                        color: item == value ? c.primary : c.textPrimary,
                        fontWeight:
                            item == value ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (item == value) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(LucideIcons.check, size: 14, color: c.primary),
                  ],
                ],
              ),
            ),
        ],
        child: Container(
          height: 36,
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelOf(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.menu.copyWith(color: c.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(LucideIcons.chevronDown, size: 14, color: c.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

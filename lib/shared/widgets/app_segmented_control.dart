import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

@immutable
class AppSegmentedItem<T> {
  const AppSegmentedItem({required this.value, required this.label});

  final T value;
  final String label;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.size = AppControlSize.regular,
    this.minHeight,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T>? onChanged;
  final AppControlSize size;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final adaptiveHeight = size == AppControlSize.compact
        ? AppControlMetrics.compactHeight
        : AppControlMetrics.regularHeight;
    final height = minHeight == null
        ? adaptiveHeight
        : math.max(adaptiveHeight, minHeight!);

    return SegmentedButton<T>(
      segments: [
        for (final item in items)
          ButtonSegment<T>(value: item.value, label: Text(item.label)),
      ],
      selected: <T>{selected},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) {
              if (selection.isNotEmpty) onChanged?.call(selection.first);
            },
      showSelectedIcon: false,
      style: ButtonStyle(
        animationDuration: AppMotion.normal,
        minimumSize: WidgetStatePropertyAll(Size(0, height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? c.primarySoft
              : c.surfaceMuted;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return c.textMuted;
          return states.contains(WidgetState.selected) ? c.primary : c.textMuted;
        }),
        overlayColor: WidgetStatePropertyAll(
          c.primary.withValues(alpha: 0.06),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return BorderSide(color: c.primary, width: 1.5);
          }
          return BorderSide(
            color: states.contains(WidgetState.selected)
                ? c.primary.withValues(alpha: 0.22)
                : c.softBorder,
          );
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

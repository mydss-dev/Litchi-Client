import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

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
    this.equalWidth = true,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T>? onChanged;
  final AppControlSize size;
  final bool equalWidth;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
      ),
      child: const SizedBox.shrink(),
    );
  }
}

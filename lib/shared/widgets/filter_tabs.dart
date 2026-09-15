import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import 'app_segmented_control.dart';

/// Horizontal filter strip backed by the shared segmented-control primitive.
class FilterTabs extends StatelessWidget {
  const FilterTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: AppSegmentedControl<int>(
        size: AppControlSize.compact,
        selected: selectedIndex,
        onChanged: onSelected,
        items: [
          for (var i = 0; i < tabs.length; i++)
            AppSegmentedItem<int>(value: i, label: tabs[i]),
        ],
      ),
    );
  }
}

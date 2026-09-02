import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';

/// Horizontal pill tab strip used on Nodes and Shop pages.
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            _Tab(
              label: tabs[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
            if (i != tabs.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: Ink(
        height: 36,
        decoration: BoxDecoration(
          color: selected ? c.primary : c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: selected ? c.primary : c.softBorder),
        ),
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.menu.copyWith(
                  color: selected ? Colors.white : c.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

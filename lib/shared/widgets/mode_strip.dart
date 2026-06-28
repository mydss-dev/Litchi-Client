import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

/// A compact three-button strip for selecting proxy mode (rule / global / direct).
class ModeStrip extends StatelessWidget {
  const ModeStrip({required this.selected, required this.onChanged, super.key});

  final ProxyMode selected;
  final ValueChanged<ProxyMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final mode in ProxyMode.values)
            Expanded(
              child: _ModeButton(
                label: switch (mode) {
                  ProxyMode.rule => '规则',
                  ProxyMode.global => '全局',
                  ProxyMode.direct => '直连',
                },
                selected: selected == mode,
                onTap: () => onChanged(mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
              color: selected ? c.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: selected
                  ? Border.all(color: c.primary.withValues(alpha: 0.22))
                  : null,
              boxShadow: selected ? AppShadows.soft(c) : null,
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: selected ? c.primary : c.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

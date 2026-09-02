import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';

/// Custom toggle switch with desktop pointer, keyboard focus and disabled state.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onChanged != null;
    final trackColor = value
        ? c.primary
        : enabled
        ? c.surfaceMuted
        : c.softBorder;

    return Semantics(
      toggled: value,
      enabled: enabled,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => onChanged!(!value) : null,
            mouseCursor:
                enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            hoverColor: c.primary.withValues(alpha: 0.05),
            focusColor: c.primary.withValues(alpha: 0.08),
            splashColor: c.primary.withValues(alpha: 0.10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: value ? c.primary : c.softBorder),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: enabled ? Colors.white : c.cardBg,
                      shape: BoxShape.circle,
                      boxShadow: value ? AppShadows.soft(c) : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

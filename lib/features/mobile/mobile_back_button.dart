import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';

class MobileBackButton extends StatelessWidget {
  const MobileBackButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: c.softBorder),
        ),
        child: Icon(LucideIcons.chevronLeft, color: c.textPrimary, size: 20),
      ),
    );
  }
}

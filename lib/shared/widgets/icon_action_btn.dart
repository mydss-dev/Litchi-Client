import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon_button.dart';

/// Compatibility wrapper for older dialog call sites.
///
/// New code should use [AppIconButton] directly. Keeping this wrapper avoids a
/// broad feature migration while all icon actions share one interaction base.
class IconActionBtn extends StatelessWidget {
  const IconActionBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.c,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Retained for source compatibility. AppIconButton resolves theme colors
  /// from context so callers no longer need to pass this value for rendering.
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: icon,
      onPressed: onTap,
      compact: true,
    );
  }
}

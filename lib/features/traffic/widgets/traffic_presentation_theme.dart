import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Keeps Traffic focused on quota and trend data while reserving the Litchi
/// brand color for progress, chart bars and active controls.
class TrafficPresentationTheme extends StatelessWidget {
  const TrafficPresentationTheme({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final dark = theme.brightness == Brightness.dark;
    final quietSurface = dark
        ? const Color(0xFF202737)
        : const Color(0xFFFFFBFC);

    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final extension in theme.extensions.values)
            if (extension is! AppColors) extension,
          colors.copyWith(
            primarySoft: quietSurface,
            shadow: colors.shadow.withValues(alpha: dark ? 0.18 : 0.025),
          ),
        ],
      ),
      child: child,
    );
  }
}

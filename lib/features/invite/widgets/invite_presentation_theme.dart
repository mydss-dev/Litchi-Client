import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Keeps Invite focused on the code and actions without turning the whole
/// page into a saturated brand surface, especially in dark mode.
class InvitePresentationTheme extends StatelessWidget {
  const InvitePresentationTheme({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final dark = theme.brightness == Brightness.dark;
    final quietBrandSurface = dark
        ? const Color(0xFF171D2B)
        : const Color(0xFFFFFBFC);

    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final extension in theme.extensions.values)
            if (extension is! AppColors) extension,
          colors.copyWith(
            primarySoft: quietBrandSurface,
            shadow: colors.shadow.withValues(alpha: dark ? 0.18 : 0.025),
          ),
        ],
      ),
      child: child,
    );
  }
}

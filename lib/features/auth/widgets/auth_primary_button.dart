import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/widgets/app_button.dart';

/// Compatibility wrapper used by auth feature pages.
///
/// Geometry, hover/focus, disabled and loading states are owned by AppButton so
/// desktop and Android keep the same interaction contract.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onPressed: onPressed,
      loading: isLoading,
      expand: true,
      trailingIcon: isLoading ? null : LucideIcons.arrowRight,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_icon_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Auth-specific compatibility wrapper around [AppTextField].
///
/// Auth pages keep their icon, required mark and reveal-toggle API while the
/// shared component owns platform geometry, focus, border and text styling.
class AuthInput extends StatefulWidget {
  const AuthInput({
    super.key,
    required this.icon,
    required this.hintText,
    this.label,
    this.requiredMark = false,
    this.controller,
    this.obscure = false,
    this.showRevealToggle = false,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
  });

  final IconData icon;
  final String hintText;
  final String? label;
  final bool requiredMark;
  final TextEditingController? controller;
  final bool obscure;
  final bool showRevealToggle;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  late bool _obscured = widget.obscure;
  final TextEditingController _fallbackController = TextEditingController();

  TextEditingController get _controller =>
      widget.controller ?? _fallbackController;

  @override
  void didUpdateWidget(covariant AuthInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscure != widget.obscure) {
      _obscured = widget.obscure;
    }
  }

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final field = AppTextField(
      controller: _controller,
      hint: widget.hintText,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      prefix: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: Icon(widget.icon, size: 18, color: c.iconMuted),
      ),
      suffix: widget.showRevealToggle
          ? AppIconButton(
              icon: _obscured ? LucideIcons.eyeOff : LucideIcons.eye,
              compact: true,
              onPressed: () => setState(() => _obscured = !_obscured),
            )
          : null,
    );

    if (widget.label == null || widget.label!.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppFieldLabel(widget.label!),
            if (widget.requiredMark) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '*',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }
}

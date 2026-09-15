import 'package:flutter/material.dart';

import '../layout/app_control_metrics.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: c.textMuted,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.label,
    this.maxLines = 1,
    this.prefixText,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.helperText,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final int maxLines;
  final String? prefixText;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final String? errorText;
  final String? helperText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final field = _buildField(context);
    if (label == null || label!.isEmpty) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label!),
        const SizedBox(height: AppSpacing.sm),
        field,
      ],
    );
  }

  Widget _buildField(BuildContext context) {
    final c = AppColors.of(context);
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      cursorColor: c.primary,
      style: AppTextStyles.input.copyWith(
        color: enabled ? c.textPrimary : c.textMuted,
      ),
      decoration: InputDecoration(
        prefixText: prefixText,
        prefix: prefixText == null ? prefix : null,
        suffix: suffix,
        hintText: hint,
        errorText: errorText,
        helperText: helperText,
        hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
        helperStyle: AppTextStyles.caption.copyWith(color: c.textMuted),
        errorStyle: AppTextStyles.caption.copyWith(color: c.danger),
        filled: true,
        fillColor: enabled
            ? c.surfaceMuted
            : c.surfaceMuted.withValues(alpha: 0.58),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 11,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.softBorder),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.softBorder.withValues(alpha: 0.65)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.danger, width: 1.5),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: AppControlMetrics.regularHeight),
      child: field,
    );
  }
}

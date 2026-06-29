import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
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
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? label;
  final int maxLines;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final field = _buildField(context);
    if (label == null || label!.isEmpty) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [AppFieldLabel(label!), const SizedBox(height: 6), field],
    );
  }

  Widget _buildField(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      style: AppTextStyles.input.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        prefixText: prefixText,
        hintText: hint,
        hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
        filled: true,
        fillColor: c.surfaceMuted,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: c.primary),
        ),
      ),
    );
  }
}

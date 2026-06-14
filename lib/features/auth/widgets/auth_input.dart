import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Auth form input (§16.9): 46px tall, 12px radius, leading icon, optional
/// password reveal toggle. Border turns primary on focus.
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
  });

  final IconData icon;
  final String hintText;
  final String? label;
  final bool requiredMark;
  final TextEditingController? controller;

  /// Whether the field starts obscured (password fields).
  final bool obscure;

  /// Show an eye/eye-off toggle on the right (password fields).
  final bool showRevealToggle;

  /// Called when the user presses Enter in this field.
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  late bool _obscured = widget.obscure;
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final input = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _focused ? c.primary : c.softBorder,
          width: _focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 17, color: c.iconMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: _obscured,
              onSubmitted: widget.onSubmitted,
              style: AppTextStyles.input.copyWith(color: c.textPrimary),
              cursorColor: c.primary,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: AppTextStyles.input.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (widget.showRevealToggle)
            GestureDetector(
              onTap: () => setState(() => _obscured = !_obscured),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(
                  _obscured ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 17,
                  color: c.iconMuted,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.label == null) return input;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label!,
              style: AppTextStyles.caption.copyWith(
                color: c.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.requiredMark) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: AppTextStyles.caption.copyWith(
                  color: c.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        input,
      ],
    );
  }
}

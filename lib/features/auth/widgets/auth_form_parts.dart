import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';

/// Small reusable pieces shared by the three auth forms.

/// Checkbox + label row (§17.5 / §18.4): 18×18, 4px radius.
class AuthCheckboxRow extends StatelessWidget {
  const AuthCheckboxRow({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.child,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  /// Optional rich label (e.g. terms with an inline link). Overrides [label].
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? c.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: value ? c.primary : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          child ??
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textSecondary,
                    fontSize: 12,
                  )),
        ],
      ),
    );
  }
}

/// Inline primary-colored tappable text (§16.9 secondary link).
class AuthLinkText extends StatelessWidget {
  const AuthLinkText({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: AppTextStyles.button.copyWith(color: c.primary),
        ),
      ),
    );
  }
}

/// "—— 或 ——" style divider with a centered label (§16.9).
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, this.label = '或'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final line = Expanded(child: Divider(color: c.border, height: 1));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label,
              style: AppTextStyles.caption.copyWith(color: c.textMuted, fontSize: 12)),
        ),
        line,
      ],
    );
  }
}

/// Centered bottom jump line, e.g. "还没有账号？ 注册账号" (§17.7 / §18.6).
class AuthBottomJump extends StatelessWidget {
  const AuthBottomJump({
    super.key,
    required this.leadingText,
    required this.actionText,
    this.onTap,
  });

  final String leadingText;
  final String actionText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(leadingText,
            style: AppTextStyles.caption.copyWith(color: c.textSecondary, fontSize: 13)),
        const SizedBox(width: 4),
        AuthLinkText(text: actionText, onTap: onTap),
      ],
    );
  }
}

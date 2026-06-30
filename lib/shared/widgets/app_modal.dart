import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../responsive/breakpoints.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'app_bottom_sheet.dart';

typedef AppAdaptiveModalBuilder =
    Widget Function(BuildContext context, bool compact);

Future<T?> showAppAdaptiveModal<T>({
  required BuildContext context,
  required AppAdaptiveModalBuilder builder,
}) {
  final compact = context.isCompact;
  if (compact) {
    return showAppBottomSheet<T>(
      context: context,
      builder: (context) => builder(context, true),
    );
  }
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (context) => builder(context, false),
  );
}

/// One modal body with a bottom-sheet shell on compact layouts and a dialog
/// shell on wide layouts.
class AppAdaptiveModal extends StatelessWidget {
  const AppAdaptiveModal({
    super.key,
    required this.compact,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.maxWidth = 460,
    this.maxHeightFactor = 0.9,
    this.showCloseButton = true,
  });

  final bool compact;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final double maxWidth;
  final double maxHeightFactor;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return AppBottomSheet(
        title: title,
        subtitle: subtitle,
        maxHeightFactor: maxHeightFactor,
        children: [child],
      );
    }
    return AppDialog(
      title: title,
      subtitle: subtitle,
      icon: icon,
      maxWidth: maxWidth,
      showCloseButton: showCloseButton,
      child: child,
    );
  }
}

class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.maxWidth = 460,
    this.showCloseButton = true,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final double maxWidth;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.card(c),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: c.primary),
                    const SizedBox(width: 9),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showCloseButton)
                    IconButton(
                      tooltip: context.l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(LucideIcons.x, size: 17, color: c.textMuted),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showHandle = true,
    this.maxHeightFactor = 0.9,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showHandle;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final view = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    // The sheet is attached to the bottom edge. The outer app window owns its
    // bottom corners, so giving the sheet another pair creates an inset card.
    const sheetRadius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.xl),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        clipBehavior: Clip.antiAlias,
        constraints: BoxConstraints(maxHeight: view.height * maxHeightFactor),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: sheetRadius,
          border: Border(top: BorderSide(color: c.softBorder)),
          boxShadow: AppShadows.soft(c),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.softBorder,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: c.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(LucideIcons.x, color: c.iconMuted, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

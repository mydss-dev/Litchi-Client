import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/core_platform_support.dart';
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
    if (CorePlatformSupport.isDesktop) {
      return _buildDesktopDialog(context);
    }
    return _buildCompactSheet(context);
  }

  Widget _buildDesktopDialog(BuildContext context) {
    final c = AppColors.of(context);
    final view = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: view.height * maxHeightFactor,
          ),
          child: Material(
            color: c.cardBg,
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Container(
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: c.softBorder),
                boxShadow: AppShadows.card(c),
              ),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModalHeader(title: title, subtitle: subtitle),
                  const SizedBox(height: 14),
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
        ),
      ),
    );
  }

  Widget _buildCompactSheet(BuildContext context) {
    final c = AppColors.of(context);
    final view = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
              _ModalHeader(title: title, subtitle: subtitle),
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

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({required this.title, required this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
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
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: Icon(LucideIcons.x, color: c.iconMuted, size: 20),
        ),
      ],
    );
  }
}

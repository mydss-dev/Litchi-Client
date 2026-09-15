import 'package:flutter/material.dart';

import '../layout/app_platform.dart';
import '../layout/app_shell_spec.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon_button.dart';

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
    this.leading,
    this.showClose = true,
    this.showHandle = true,
    this.maxHeightFactor = 0.9,
    this.maxWidth = 560,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showClose;
  final List<Widget> children;
  final bool showHandle;
  final double maxHeightFactor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final navigation = AppShellSpec.navigationFor(AppPlatform.current);
    if (navigation == AppNavigationMode.sidebar) {
      return _buildDesktopDialog(context);
    }
    return _buildCompactSheet(context);
  }

  Widget _buildDesktopDialog(BuildContext context) {
    final c = AppColors.of(context);
    final view = MediaQuery.sizeOf(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl + bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: view.height * maxHeightFactor,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card(c),
            ),
            child: Material(
              color: c.cardBg,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Container(
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: c.softBorder),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModalHeader(
                      title: title,
                      subtitle: subtitle,
                      leading: leading,
                      showClose: showClose,
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
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
                  width: 40,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: c.softBorder,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _ModalHeader(
                title: title,
                subtitle: subtitle,
                leading: leading,
                showClose: showClose,
              ),
              const SizedBox(height: AppSpacing.md),
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
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.showClose,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
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
        if (showClose)
          AppIconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: Icons.close,
            compact: true,
          ),
      ],
    );
  }
}

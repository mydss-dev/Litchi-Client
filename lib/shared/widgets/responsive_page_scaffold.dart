import 'package:flutter/material.dart';

import '../../app/core_platform_support.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'page_header.dart';
import 'page_status_cards.dart';

/// Shared page chrome for account/support sub-pages. Desktop uses the
/// persistent sidebar and a wide title/subtitle header; compact platforms keep
/// the bottom-nav/back-button presentation.
class ResponsivePageScaffold extends StatelessWidget {
  const ResponsivePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.compactTitle,
    required this.primaryCompact,
    required this.onBack,
    required this.children,
    this.onRefresh,
    this.compactSubtitle,
    this.trailing,
    this.compactBodySpacing = 16,
  });

  final String title;
  final String subtitle;
  final String compactTitle;
  final String? compactSubtitle;
  final bool primaryCompact;
  final Future<void> Function()? onRefresh;
  final VoidCallback onBack;
  final List<Widget> children;
  final Widget? trailing;
  final double compactBodySpacing;

  @override
  Widget build(BuildContext context) {
    if (CorePlatformSupport.isDesktop) return _buildDesktop(context);

    final list = ListView(
      shrinkWrap: CorePlatformSupport.isDesktop,
      physics: CorePlatformSupport.isDesktop
          ? const NeverScrollableScrollPhysics()
          : (onRefresh == null ? null : const AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.zero,
      children: [
        if (primaryCompact)
          CompactPageHeader(
            title: compactTitle,
            subtitle: compactSubtitle ?? subtitle,
            trailing: trailing,
          )
        else
          _CompactBackHeader(title: title, onBack: onBack, trailing: trailing),
        SizedBox(height: compactBodySpacing),
        ...children,
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }

  Widget _buildDesktop(BuildContext context) {
    final c = AppColors.of(context);
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.pageTitle.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
                if (onRefresh != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .refreshIndicatorSemanticLabel,
                    onPressed: () async => onRefresh!(),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CompactBackHeader extends StatelessWidget {
  const _CompactBackHeader({
    required this.title,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PageBackButton(onTap: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
          ),
        ),
        ...?(trailing == null ? null : [trailing!]),
      ],
    );
  }
}

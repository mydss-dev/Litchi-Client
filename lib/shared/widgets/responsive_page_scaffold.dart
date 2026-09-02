import 'package:flutter/material.dart';

import '../../app/core_platform_support.dart';
import '../theme/app_text_styles.dart';
import 'page_header.dart';
import 'page_status_cards.dart';

/// Shared page chrome for account/support sub-pages. Desktop is content-first:
/// the persistent sidebar already names the destination, so only real page
/// actions are surfaced above content. Compact navigation remains unchanged.
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
      physics: onRefresh == null ? null : const AlwaysScrollableScrollPhysics(),
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
    final hasActions = trailing != null || onRefresh != null;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasActions) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onRefresh != null)
                      SizedBox(
                        width: 34,
                        height: 34,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .refreshIndicatorSemanticLabel,
                          onPressed: () async => onRefresh!(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          iconSize: 17,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    if (trailing != null) ...[
                      if (onRefresh != null) const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
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

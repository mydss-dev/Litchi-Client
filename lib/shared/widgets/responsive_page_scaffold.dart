import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import 'page_header.dart';
import 'page_status_cards.dart';

/// Shared page chrome for sub-pages. The app is a fixed-size single-layout
/// window, so there is no wide/sidebar branch — this always renders the
/// compact (bottom-nav) chrome: a full header for primary tabs, or a
/// back-button header for hub sub-pages.
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

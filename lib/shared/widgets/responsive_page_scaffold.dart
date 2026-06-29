import 'package:flutter/material.dart';

import '../responsive/breakpoints.dart';
import '../theme/app_text_styles.dart';
import 'page_header.dart';
import 'page_status_cards.dart';

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
    this.showWideRefresh = true,
    this.trailing,
    this.compactBodySpacing = 16,
    this.showWideBack = true,
    this.showWideTrailing = true,
  });

  final String title;
  final String subtitle;
  final String compactTitle;
  final String? compactSubtitle;
  final bool primaryCompact;
  final Future<void> Function()? onRefresh;
  final VoidCallback onBack;
  final List<Widget> children;
  final bool showWideRefresh;
  final Widget? trailing;
  final double compactBodySpacing;
  final bool showWideBack;
  final bool showWideTrailing;

  @override
  Widget build(BuildContext context) {
    return context.isCompact ? _buildCompact(context) : _buildWide();
  }

  Widget _buildWide() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (showWideBack) ...[
                PageBackButton(onTap: onBack, tooltip: '返回我的'),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: PageHeader(title: title, subtitle: subtitle),
              ),
              if (showWideRefresh && onRefresh != null) ...[
                const SizedBox(width: 10),
                RefreshIconButton(onTap: onRefresh!),
              ],
              if (showWideTrailing && trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
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

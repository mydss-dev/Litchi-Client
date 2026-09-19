import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Shared dimensions for the new Dashboard and the other V3 pages.
/// LayoutBuilder widths are local pane widths, not the overall window width.
abstract final class V3Layout {
  static const double pageGutter = 18;
  static const double cardRadius = 18;
  static const double cardGap = 12;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(18, 18, 18, 28);

  static bool canSplit({
    required double paneWidth,
    required double primaryMin,
    required double secondaryMin,
    double gap = cardGap,
  }) => paneWidth - pageGutter * 2 >= primaryMin + secondaryMin + gap;
}

/// Exactly the Dashboard's visual card: dark hero, independently light surface.
class V3WorkspaceCard extends StatelessWidget {
  const V3WorkspaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? p.hero : p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

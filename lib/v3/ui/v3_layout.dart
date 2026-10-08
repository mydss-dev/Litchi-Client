import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Shared dimensions for the new Dashboard and the other V3 pages.
/// LayoutBuilder widths are local pane widths, not the overall window width.
abstract final class V3Layout {
  static const double pageGutter = 18;
  static const double cardRadius = V3Radius.card;
  static const double cardGap = 12;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(18, 18, 18, 28);

  /// Breakpoint for page content measured against the page's own width —
  /// the window minus the 200dp desktop rail, not the window. At the 900x700
  /// acceptance window the content pane is ~688dp, so pane breakpoints must
  /// stay well below that or pages render their phone layout on the desktop.
  static const double paneCompact = 560;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        // Both modes elevate: the card sits one tonal step above the canvas,
        // and fills with the palette's two-step vertical wash ([V3Palette
        // .cardGradient]) instead of a flat color — light from above gives
        // the card quiet volume, the way DLSS5's glass cards and Apple's
        // materials shade themselves. The hairline rides on top: line and
        // light together are what keep it from reading flat.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.cardGradient,
        ),
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

import 'package:flutter/widgets.dart';

import 'layout_scope.dart';

/// Width breakpoints for the single responsive UI.
///
/// The app no longer forks on platform (Android vs desktop). The layout is
/// chosen by the *available width*, so a narrow desktop window shows the
/// compact (bottom-nav) layout and a wide tablet shows the full (sidebar)
/// layout. One set of pages, adapted by width.
abstract final class Breakpoints {
  /// Below this width the compact (mobile-style) layout is used.
  static const double compact = 720;

  /// Comfortable reading-width cap for centered page content on wide screens.
  static const double contentMax = 1080;

  /// True when [width] should use the compact layout.
  static bool isCompactWidth(double width) => width < compact;
}

extension ResponsiveContext on BuildContext {
  /// True when the content area is in the compact (mobile) range.
  ///
  /// Reads the global [LayoutScope] injected by the shell, which uses the
  /// **content-area** width (not the whole window).  This guarantees every
  /// page makes the same compact / wide decision at any given window size.
  bool get isCompact => LayoutScope.of(this).isCompact;

  /// Content-area width as reported by [LayoutScope].
  double get contentWidth => LayoutScope.of(this).contentWidth;
}

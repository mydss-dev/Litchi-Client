import 'package:flutter/widgets.dart';

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
  /// True when the current window width is in the compact (mobile) range.
  ///
  /// At the shell level prefer a [LayoutBuilder]'s constraints (more precise);
  /// use this inside a page when only the overall window width matters.
  bool get isCompact =>
      MediaQuery.sizeOf(this).width < Breakpoints.compact;
}

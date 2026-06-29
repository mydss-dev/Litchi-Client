import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

/// Global layout-mode source of truth.  Injected by the shell inside a
/// [LayoutBuilder] using the **content-area** width — not the whole window —
/// so every page sees the same compact / wide decision at any given window
/// size.
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.isCompact,
    required this.contentWidth,
    required super.child,
  });

  final bool isCompact;
  final double contentWidth;

  static LayoutScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LayoutScope>();
    assert(
      scope != null,
      'LayoutScope.of() must be called inside a LayoutScope subtree',
    );
    return scope!;
  }

  /// Fallback for call sites that may run before the shell has wrapped the
  /// tree (edge cases during auth flow / splash).  Falls back to the whole
  /// window width, which is correct for the logged-out compact window.
  static LayoutScope maybeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LayoutScope>();
    if (scope != null) return scope;
    final mq = MediaQuery.maybeOf(context);
    final w = mq?.size.width ?? 0;
    return LayoutScope(
      isCompact: w < Breakpoints.compact,
      contentWidth: w,
      child: const SizedBox.shrink(),
    );
  }

  @override
  bool updateShouldNotify(LayoutScope old) =>
      old.isCompact != isCompact || old.contentWidth != contentWidth;
}

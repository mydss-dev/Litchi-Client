import 'package:flutter/widgets.dart';

import 'app_layout.dart';

typedef AppAdaptiveBuilder =
    Widget Function(BuildContext context, AppLayoutSnapshot layout);

/// Shared width-based layout switch for feature pages.
///
/// Features should prefer this primitive over embedding their own width checks.
/// Platform-specific native behavior belongs elsewhere; this widget only
/// chooses presentation geometry from the available width.
class AppAdaptiveLayout extends StatelessWidget {
  const AppAdaptiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  final AppAdaptiveBuilder compact;
  final AppAdaptiveBuilder? medium;
  final AppAdaptiveBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = AppLayoutSnapshot.fromSize(
          Size(width, constraints.maxHeight),
        );

        return switch (layout.layoutClass) {
          AppLayoutClass.compact => compact(context, layout),
          AppLayoutClass.medium =>
            (medium ?? expanded ?? compact)(context, layout),
          AppLayoutClass.expanded =>
            (expanded ?? medium ?? compact)(context, layout),
        };
      },
    );
  }
}

import 'package:flutter/widgets.dart';

import '../layout/app_layout.dart';
import '../theme/app_spacing.dart';

/// Shared content measure for Windows, macOS and Android feature pages.
///
/// The navigation shell still owns outer scrolling and safe-area behavior. This
/// widget keeps feature content width, alignment and in-page padding consistent
/// across layout classes without forcing each feature to invent breakpoints.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.body,
    this.maxContentWidth,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xxl),
    this.alignment = Alignment.topLeft,
  });

  final Widget body;

  /// Optional feature-specific cap. When omitted the shared layout system picks
  /// the cap from the available width.
  final double? maxContentWidth;
  final EdgeInsetsGeometry padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final effectiveMaxWidth =
            maxContentWidth ??
            AppLayoutMetrics.contentMaxWidthFor(availableWidth);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
            child: Padding(padding: padding, child: body),
          ),
        );
      },
    );
  }
}

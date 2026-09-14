import 'package:flutter/widgets.dart';

import '../theme/app_spacing.dart';

/// Consistent desktop content bounds. The shell keeps ownership of scrolling;
/// this widget only owns a page's horizontal measure and in-page padding.
class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    super.key,
    required this.body,
    this.maxContentWidth = 1120,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xxl),
  });

  final Widget body;
  final double maxContentWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: Padding(padding: padding, child: body),
    ),
  );
}

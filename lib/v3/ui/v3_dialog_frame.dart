import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';
import 'v3_layout.dart';

/// Shared outline and radius for V3 modal surfaces, including checkout and
/// confirmation dialogs that manage their own content layout.
RoundedRectangleBorder v3DialogShape(V3Palette palette) =>
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(V3Layout.cardRadius),
      side: BorderSide(color: palette.line),
    );

/// A bounded, scrollable modal for forms and payment states. It uses the same
/// surface, border and radius as the redesigned dashboard's cards. Dialog
/// insets and keyboard-safe height are calculated from the route viewport;
/// the individual forms retain their existing submit and navigation behavior.
class V3DialogFrame extends StatelessWidget {
  const V3DialogFrame({
    super.key,
    required this.child,
    this.width = 440,
    this.padding = const EdgeInsets.all(20),
    this.scrollable = true,
  });

  final Widget child;
  final double width;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final palette = V3Palette.of(context);
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.bottom -
        media.padding.top -
        media.padding.bottom -
        32;
    final maxHeight = availableHeight.clamp(0.0, 720.0).toDouble();
    final contents = scrollable
        ? SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: padding,
            child: child,
          )
        : Padding(padding: padding, child: child);

    return Dialog(
      backgroundColor: palette.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: v3DialogShape(palette),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SizedBox(width: width, child: contents),
      ),
    );
  }
}

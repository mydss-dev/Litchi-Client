import 'package:flutter/material.dart';

import '../../app/core_platform_support.dart';
import 'app_bottom_sheet.dart';

typedef AppAdaptiveModalBuilder = Widget Function(BuildContext context);

Future<T?> showAppAdaptiveModal<T>({
  required BuildContext context,
  required AppAdaptiveModalBuilder builder,
}) {
  if (CorePlatformSupport.isDesktop) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: builder,
    );
  }
  return showAppBottomSheet<T>(context: context, builder: builder);
}

/// Shared adaptive modal body. Compact platforms render this as a bottom sheet;
/// desktop routes render the same content in the centered desktop surface owned
/// by [AppBottomSheet].
class AppAdaptiveModal extends StatelessWidget {
  const AppAdaptiveModal({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.maxHeightFactor = 0.9,
    this.maxWidth = 560,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double maxHeightFactor;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      subtitle: subtitle,
      maxHeightFactor: maxHeightFactor,
      maxWidth: maxWidth,
      children: [child],
    );
  }
}

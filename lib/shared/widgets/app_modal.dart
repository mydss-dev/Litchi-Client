import 'package:flutter/material.dart';

import 'app_bottom_sheet.dart';

typedef AppAdaptiveModalBuilder = Widget Function(BuildContext context);

Future<T?> showAppAdaptiveModal<T>({
  required BuildContext context,
  required AppAdaptiveModalBuilder builder,
}) {
  return showAppBottomSheet<T>(context: context, builder: builder);
}

/// One modal body, always presented as a bottom sheet. The app is a fixed-size
/// single-layout window, so there is no wide dialog shell.
class AppAdaptiveModal extends StatelessWidget {
  const AppAdaptiveModal({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.maxHeightFactor = 0.9,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: title,
      subtitle: subtitle,
      maxHeightFactor: maxHeightFactor,
      children: [child],
    );
  }
}

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../models/app_models.dart';
import 'app_segmented_control.dart';

/// Proxy mode selector. The public API stays compatible while interaction and
/// geometry are owned by the shared segmented-control primitive.
class ModeStrip extends StatelessWidget {
  const ModeStrip({
    required this.selected,
    required this.onChanged,
    this.buttonHeight = 42,
    this.padding = 5,
    super.key,
  });

  final ProxyMode selected;
  final ValueChanged<ProxyMode> onChanged;
  final double buttonHeight;

  /// Kept for source compatibility with older call sites. Shared segmented
  /// geometry now owns its internal padding.
  final double padding;

  @override
  Widget build(BuildContext context) {
    return AppSegmentedControl<ProxyMode>(
      selected: selected,
      onChanged: onChanged,
      minHeight: buttonHeight,
      items: [
        AppSegmentedItem(
          value: ProxyMode.rule,
          label: context.l10n.ruleMode,
        ),
        AppSegmentedItem(
          value: ProxyMode.global,
          label: context.l10n.globalMode,
        ),
        AppSegmentedItem(
          value: ProxyMode.direct,
          label: context.l10n.directMode,
        ),
      ],
    );
  }
}

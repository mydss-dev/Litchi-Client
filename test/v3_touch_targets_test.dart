import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'visual/v3_visual_fixture.dart';

/// Touch-target invariants for the smallest interactive controls in v3.
///
/// The narrowest control in the app is the settings segmented control, whose
/// height comes from its label's line box plus its own padding — a value that
/// silently drifts when either the font size or the padding changes. These
/// tests measure the rendered hit area rather than trusting a comment that
/// says "this is 44dp".
class _Controller extends VisualV3Controller {
  _Controller(super.page);
}

Future<void> _pump(WidgetTester tester, AppPage page, Size size) async {
  // Android rather than Windows: at 390dp wide the desktop window chrome
  // overflows the test font, and compact is the layout under test anyway.
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  await tester.binding.setSurfaceSize(size);
  final controller = _Controller(page);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.light(),
      home: AppScope(controller: controller, child: const V3Shell()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // 44dp is the target size WCAG 2.5.5 asks of a pointer target, and the
  // floor the design system commits to for every control it draws.
  const minimum = 44.0;

  testWidgets('settings segmented control clears the touch-target floor', (
    tester,
  ) async {
    try {
      await _pump(tester, AppPage.settings, const Size(390, 844));
      final segments = find.descendant(
        of: find.byType(FittedBox),
        matching: find.byType(InkWell),
      );
      expect(
        segments,
        findsWidgets,
        reason: 'the segmented control should render in a FittedBox',
      );
      for (final element in segments.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          rect.height,
          greaterThanOrEqualTo(minimum),
          reason:
              'segment ${rect.width.toStringAsFixed(0)}dp wide is only '
              '${rect.height.toStringAsFixed(1)}dp tall',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('region chips clear the touch-target floor', (tester) async {
    try {
      await _pump(tester, AppPage.nodes, const Size(390, 844));
      final chips = find.byType(ChoiceChip);
      expect(chips, findsWidgets);
      for (final element in chips.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          rect.height,
          greaterThanOrEqualTo(minimum),
          reason:
              'a region chip is only '
              '${rect.height.toStringAsFixed(1)}dp tall',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

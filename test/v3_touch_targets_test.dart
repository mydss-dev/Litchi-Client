import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_node_coverage_map.dart';

import 'visual/v3_visual_fixture.dart';

/// Touch-target invariants for the smallest interactive controls in v3.
///
/// These tests measure the rendered hit area rather than trusting a comment
/// that says "this is 44dp". The nodes overview is intentionally read-only;
/// interactive region chips are measured on the map's interactive variant.
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
      // The segmented control is now a full-width row, not a FittedBox-scaled
      // one, so the segments are found by their own key rather than by the
      // wrapper that used to scale them.
      final segments = find.byWidgetPredicate(
        (widget) =>
            widget is InkWell &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'v3-settings-segment',
            ),
      );
      expect(
        segments,
        findsWidgets,
        reason: 'the segmented control should render its segments',
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

  testWidgets('nodes overview does not expose interactive region chips', (
    tester,
  ) async {
    try {
      await _pump(tester, AppPage.nodes, const Size(390, 844));
      expect(find.byType(ChoiceChip), findsNothing,
          reason: 'the nodes overview is informational, not a region filter');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('interactive map region chips clear the touch-target floor', (
    tester,
  ) async {
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: V3NodeCoverageMap(
              nodes: const [
                NodeModel(
                  id: 'hk-01',
                  name: 'Hong Kong',
                  flag: '',
                  code: 'HK',
                  englishName: 'Hong Kong',
                  latency: 32,
                  region: NodeRegion.asia,
                ),
              ],
              selectedCode: null,
              onSelected: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final chips = find.byType(ChoiceChip);
      expect(chips, findsWidgets,
          reason: 'the interactive map must retain its region filters');
      for (final element in chips.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          rect.height,
          greaterThanOrEqualTo(minimum),
          reason:
              'an interactive region chip is only '
              '${rect.height.toStringAsFixed(1)}dp tall',
        );
      }
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_settings_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'visual/v3_visual_fixture.dart';

/// Touch-target invariants for the smallest interactive controls in v3.
///
/// These tests measure the rendered hit area rather than trusting a comment
/// that says "this is 44dp". The nodes overview and the map's interactive
/// variant both expose region filters, so both must clear the floor.
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

  testWidgets('settings dropdowns clear the touch-target floor', (
    tester,
  ) async {
    try {
      await _pump(tester, AppPage.settings, const Size(390, 844));
      // The four settings dropdowns (theme/language/connection/DNS) carry
      // their own keys; each trigger's rect is the tap target being measured.
      // The connection-method row renders on desktop platforms only.
      final desktopTools = v3HasDesktopSystemTools(defaultTargetPlatform);
      final keys = <String>[
        'v3-theme-select',
        'v3-language-select',
        if (desktopTools) 'v3-network-mode-select',
        'v3-dns-select',
      ];
      for (final key in keys) {
        final trigger = find.byKey(ValueKey<String>(key));
        expect(trigger, findsOneWidget, reason: '$key should render');
        final rect = tester.getRect(trigger);
        expect(
          rect.height,
          greaterThanOrEqualTo(minimum),
          reason:
              'the $key trigger is only ${rect.height.toStringAsFixed(1)}dp tall',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('nodes overview region filters clear the touch-target floor', (
    tester,
  ) async {
    try {
      await _pump(tester, AppPage.nodes, const Size(390, 844));
      final chips = find.byType(ChoiceChip);
      expect(chips, findsWidgets,
          reason: 'the overview filters its list by region');
      for (final element in chips.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(
          rect.height,
          greaterThanOrEqualTo(minimum),
          reason:
              'an overview region chip is only '
              '${rect.height.toStringAsFixed(1)}dp tall',
        );
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

}

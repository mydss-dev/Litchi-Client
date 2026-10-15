import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_components.dart';

/// Round-3 audit N23: the touch branch of [V3Switch] promises the 48dp
/// hit-target floor (Material 3 and Apple HIG agree); the desktop branch keeps
/// its 52x30 silhouette. Measure the rendered hit area instead of trusting
/// the comment in v3_components.dart.
void main() {
  testWidgets('V3Switch touch branch clears the 48dp hit-target floor', (
    tester,
  ) async {
    // The override is cleared in the body: the framework checks foundation
    // invariants before tear-downs.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: V3Theme.light(),
          home: Scaffold(
            body: Center(child: V3Switch(value: true, onChanged: (_) {})),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(V3Switch));
      expect(rect.height, greaterThanOrEqualTo(48),
          reason: 'the touch hit target is only '
              '${rect.height.toStringAsFixed(1)}dp tall');
      expect(rect.width, greaterThanOrEqualTo(44),
          reason: 'the touch hit target is only '
              '${rect.width.toStringAsFixed(1)}dp wide');

      // The ink layer wraps the track, so a press anywhere in the 52x48 box
      // toggles — the extra height is part of the target, not decoration.
      final pressable = find.descendant(
        of: find.byType(V3Switch),
        matching: find.byType(V3Pressable),
      );
      expect(pressable, findsOneWidget);
      expect(tester.getRect(pressable), rect);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('a tap in the extra height above the track toggles', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      var value = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: V3Theme.light(),
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, setState) => V3Switch(
                  value: value,
                  onChanged: (next) => setState(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byType(V3Switch));
      // The track is 30dp tall centered in the 48dp target; tap inside the
      // extra band the touch branch adds — where a bare 52x30 target would
      // have missed.
      await tester.tapAt(Offset(rect.center.dx, rect.top + 4));
      await tester.pump();

      expect(value, isFalse, reason: 'the 48dp wrap belongs to the hit target');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

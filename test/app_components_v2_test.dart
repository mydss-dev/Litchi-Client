import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/layout/app_control_metrics.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/widgets/app_button.dart';
import 'package:litchi_client/shared/widgets/app_segmented_control.dart';

void main() {
  group('AppControlMetrics', () {
    test('uses compact pointer geometry on desktop', () {
      expect(
        AppControlMetrics.heightFor(AppPlatformKind.windows),
        AppControlMetrics.pointerRegularHeight,
      );
      expect(
        AppControlMetrics.heightFor(
          AppPlatformKind.macOS,
          size: AppControlSize.compact,
        ),
        AppControlMetrics.pointerCompactHeight,
      );
      expect(
        AppControlMetrics.iconButtonExtentFor(AppPlatformKind.windows),
        AppControlMetrics.pointerIconButtonExtent,
      );
    });

    test('uses touch-safe geometry on Android', () {
      expect(
        AppControlMetrics.heightFor(AppPlatformKind.android),
        AppControlMetrics.touchRegularHeight,
      );
      expect(
        AppControlMetrics.heightFor(
          AppPlatformKind.android,
          size: AppControlSize.compact,
        ),
        AppControlMetrics.touchCompactHeight,
      );
      expect(
        AppControlMetrics.iconButtonExtentFor(AppPlatformKind.android),
        AppControlMetrics.touchIconButtonExtent,
      );
    });
  });

  testWidgets('AppButton invokes callback and loading disables it', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Save', onPressed: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Save',
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });

  testWidgets('AppSegmentedControl reports the selected value', (tester) async {
    var selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSegmentedControl<int>(
            selected: selected,
            onChanged: (value) => selected = value,
            items: const [
              AppSegmentedItem(value: 0, label: 'Rule'),
              AppSegmentedItem(value: 1, label: 'Global'),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Global'));
    expect(selected, 1);
  });
}

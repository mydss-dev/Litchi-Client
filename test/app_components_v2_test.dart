import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/layout/app_control_metrics.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/widgets/app_button.dart';
import 'package:litchi_client/shared/widgets/app_icon_button.dart';
import 'package:litchi_client/shared/widgets/app_segmented_control.dart';
import 'package:litchi_client/shared/widgets/app_toast.dart';
import 'package:litchi_client/shared/widgets/page_status_cards.dart';
import 'package:litchi_client/shared/widgets/search_input.dart';

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

  testWidgets('AppIconButton loading disables taps and shows progress', (
    tester,
  ) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppIconButton(
            icon: Icons.refresh,
            loading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(taps, 0);
  });

  testWidgets('SearchInput clear keeps the onChanged contract', (tester) async {
    final changes = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchInput(onChanged: changes.add),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Tokyo');
    await tester.pump();
    expect(changes.last, 'Tokyo');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(changes.last, '');
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

  testWidgets('PageIconButton keeps existing callback contract', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh',
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    expect(taps, 1);
  });

  testWidgets('AppToast appears in overlay and clears after duration', (
    tester,
  ) async {
    late OverlayState overlay;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            overlay = Overlay.of(context, rootOverlay: true);
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    AppToast.showInOverlay(
      overlay,
      'Saved',
      duration: const Duration(milliseconds: 300),
    );
    await tester.pump();
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Saved'), findsNothing);
  });
}

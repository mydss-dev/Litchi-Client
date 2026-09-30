import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

/// The visual fixture freezes [page]; the press ink needs a shell that can
/// actually navigate so the tap-path assertion means something.
class _InkNavController extends VisualV3Controller {
  _InkNavController() : super(AppPage.dashboard);
  AppPage _current = AppPage.dashboard;
  @override
  AppPage get page => _current;
  @override
  void goToPage(AppPage target) {
    if (!isPageEnabled(target)) return;
    _current = target;
    notifyListeners();
  }
}

const _snapshotsEnabled = bool.fromEnvironment('LITCHI_VISUAL_SNAPSHOTS');

/// Captured window pixels — the ink is an [InkFeature] on the pressable's
/// Material, invisible to finder-based assertions. Returns the pixels and the
/// captured pixel width (the test surface runs at DPR 1).
Future<(Uint8List, int)> _snapshot(WidgetTester tester) async {
  RenderObject obj = tester.renderObject(find.byType(V3Shell));
  while (obj is! RenderRepaintBoundary) {
    obj = obj.parent!;
  }
  final image = await obj.toImage();
  final bytes = await tester.binding.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
  );
  return (bytes!.buffer.asUint8List(), image.width);
}

/// Average of a 5x5 block around [point] (physical pixels), to ride out glyph
/// anti-aliasing at a single pixel.
List<double> _sampleBlock(Uint8List pixels, int width, Offset point) {
  final sums = List<double>.filled(3, 0);
  var count = 0;
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -2; dx <= 2; dx++) {
      final x = (point.dx.round() + dx).clamp(0, width - 1);
      final y = (point.dy.round() + dy).clamp(0, 1 << 20);
      final i = (y * width + x) * 4;
      sums[0] += pixels[i];
      sums[1] += pixels[i + 1];
      sums[2] += pixels[i + 2];
      count++;
    }
  }
  return [sums[0] / count, sums[1] / count, sums[2] / count];
}

void main() {
  for (final themeMode in [ThemeMode.dark, ThemeMode.light]) {
    final themeName = themeMode == ThemeMode.dark ? 'dark' : 'light';

    testWidgets('held rail item paints lychee ink ($themeName)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.binding.setSurfaceSize(const Size(900, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _InkNavController();
        addTearDown(controller.disposeVisual);
        await tester.pumpWidget(
          AppScope(
            controller: controller,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: V3Theme.light(),
              darkTheme: V3Theme.dark(),
              themeMode: themeMode,
              home: const V3Shell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final item = find.byKey(railItemKey(AppPage.nodes));
        expect(item, findsOneWidget);

        // The input path itself: a plain tap must navigate.
        await tester.tap(item, warnIfMissed: true);
        await tester.pumpAndSettle();
        expect(
          controller.page,
          AppPage.nodes,
          reason: 'a tap must reach the rail item at all',
        );

        // Back on the dashboard so the pressed item is an unselected one.
        controller.goToPage(AppPage.dashboard);
        await tester.pumpAndSettle();

        final (idle, width) = await _snapshot(tester);
        final center = tester.getCenter(item);

        final gesture = await tester.startGesture(
          center,
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        );
        // Right after down the highlight sits at alpha 0 (the fade-in
        // starts there); settle it to full opacity before sampling.
        await tester.pumpAndSettle();
        final (pressed, pressedWidth) = await _snapshot(tester);
        expect(pressedWidth, width);
        if (_snapshotsEnabled) {
          await expectLater(
            find.byType(V3Shell),
            matchesGoldenFile(
              'goldens/press_ink_rail_${themeName}_pressed.png',
            ),
          );
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 300));

        expect(pressed.length, idle.length);
        var differing = 0;
        for (var i = 0; i < idle.length; i += 4) {
          if (idle[i] != pressed[i] ||
              idle[i + 1] != pressed[i + 1] ||
              idle[i + 2] != pressed[i + 2]) {
            differing++;
          }
        }
        expect(
          differing,
          greaterThan(0),
          reason: 'a held press must visibly repaint the window',
        );

        // Sample inside the pill, right of the label and clear of glyphs.
        // Lychee @12% lifts the red channel far past the others; the idle
        // hero ground is nearly grey.
        final scale = width / 900;
        final point = Offset(center.dx + 45, center.dy) * scale;
        final idleRgb = _sampleBlock(idle, width, point);
        final pressedRgb = _sampleBlock(pressed, width, point);
        if (themeMode == ThemeMode.dark) {
          // Dark: the near-grey hero ground gains a red lift.
          expect(
            pressedRgb[0] - idleRgb[0],
            greaterThan(12),
            reason:
                'press ink must lift the red channel at $point '
                '(idle ${idleRgb.map((c) => c.toStringAsFixed(1)).toList()}, '
                'pressed ${pressedRgb.map((c) => c.toStringAsFixed(1)).toList()})',
          );
        } else {
          // Light: lychee is barely redder than the sage ground in red, but
          // pulls green and blue down hard.
          expect(
            pressedRgb[2],
            lessThan(idleRgb[2] - 8),
            reason:
                'press ink must pull the blue channel down at $point '
                '(idle ${idleRgb.map((c) => c.toStringAsFixed(1)).toList()}, '
                'pressed ${pressedRgb.map((c) => c.toStringAsFixed(1)).toList()})',
          );
        }
        expect(
          pressedRgb[0] - pressedRgb[1],
          greaterThan(5),
          reason:
              'press ink must read pink, not grey, at $point '
              '(pressed ${pressedRgb.map((c) => c.toStringAsFixed(1)).toList()})',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('held account card paints lychee ink ($themeName)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.binding.setSurfaceSize(const Size(900, 700));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _InkNavController();
        addTearDown(controller.disposeVisual);
        await tester.pumpWidget(
          AppScope(
            controller: controller,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: V3Theme.light(),
              darkTheme: V3Theme.dark(),
              themeMode: themeMode,
              home: const V3Shell(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(kAccountCardKey);
        expect(card, findsOneWidget);

        final (idle, _) = await _snapshot(tester);
        final gesture = await tester.startGesture(
          tester.getCenter(card),
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryButton,
        );
        await tester.pumpAndSettle();
        final (pressed, _) = await _snapshot(tester);
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 300));

        expect(pressed.length, idle.length);
        var differing = 0;
        for (var i = 0; i < idle.length; i += 4) {
          if (idle[i] != pressed[i] ||
              idle[i + 1] != pressed[i + 1] ||
              idle[i + 2] != pressed[i + 2]) {
            differing++;
          }
        }
        expect(
          differing,
          greaterThan(0),
          reason: 'a held press on the account card must visibly repaint',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

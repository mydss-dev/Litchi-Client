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

/// The visual fixture freezes [page]; hovering a rail item needs no
/// navigation, but reusing the navigable controller keeps the harness
/// identical to the press-ink test.
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

/// Captured window pixels — the hover wash is an [InkFeature] on the
/// pressable's Material, invisible to finder-based assertions.
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

    testWidgets('hovered rail item paints a quiet ink wash ($themeName)', (
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

        final (idle, width) = await _snapshot(tester);

        // Hover, not press: a mouse pointer moves onto the item with no
        // button held — exactly the desktop input the wash exists for.
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: Offset.zero);
        addTearDown(gesture.removePointer);
        await gesture.moveTo(tester.getCenter(item));
        // Let the hover overlay fade all the way in before sampling.
        await tester.pumpAndSettle();
        final (hovered, hoveredWidth) = await _snapshot(tester);
        expect(hoveredWidth, width);
        if (_snapshotsEnabled) {
          await expectLater(
            find.byType(V3Shell),
            matchesGoldenFile(
              'goldens/hover_ink_rail_${themeName}_hovered.png',
            ),
          );
        }
        await gesture.moveTo(Offset.zero);

        expect(hovered.length, idle.length);
        var differing = 0;
        for (var i = 0; i < idle.length; i += 4) {
          if (idle[i] != hovered[i] ||
              idle[i + 1] != hovered[i + 1] ||
              idle[i + 2] != hovered[i + 2]) {
            differing++;
          }
        }
        expect(
          differing,
          greaterThan(0),
          reason: 'a hovered rail item must visibly repaint the window',
        );

        // Sample inside the item, right of the label and clear of glyphs.
        final scale = width / 900;
        final point =
            Offset(tester.getCenter(item).dx + 45, 0) * scale +
            Offset(0, tester.getCenter(item).dy * scale);
        final idleRgb = _sampleBlock(idle, width, point);
        final hoveredRgb = _sampleBlock(hovered, width, point);
        if (themeMode == ThemeMode.dark) {
          // Dark: the light ink wash lifts every channel. A lychee highlight
          // here would be a bug — hover is ink, not pink — but at 4% the
          // neutral lift stays far below the pressed highlight's red jump.
          expect(
            hoveredRgb[0] - idleRgb[0],
            greaterThan(3),
            reason:
                'hover ink must lift the red channel at $point '
                '(idle ${idleRgb.map((c) => c.toStringAsFixed(1)).toList()}, '
                'hovered ${hoveredRgb.map((c) => c.toStringAsFixed(1)).toList()})',
          );
          expect(
            hoveredRgb[0] - hoveredRgb[1],
            lessThan(10),
            reason:
                'hover ink must read neutral, not pink, at $point '
                '(hovered ${hoveredRgb.map((c) => c.toStringAsFixed(1)).toList()})',
          );
        } else {
          // Light: the dark ink wash pulls every channel down.
          expect(
            idleRgb[0] - hoveredRgb[0],
            greaterThan(3),
            reason:
                'hover ink must darken the red channel at $point '
                '(idle ${idleRgb.map((c) => c.toStringAsFixed(1)).toList()}, '
                'hovered ${hoveredRgb.map((c) => c.toStringAsFixed(1)).toList()})',
          );
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

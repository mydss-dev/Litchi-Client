import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

/// WCAG 2.1 relative luminance of [c] (alpha is ignored: every ground here is
/// opaque, and tinted panels are flattened by [_over] first).
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  // Color components are in the 0..1 extended sRGB space.
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Flattens [top] at [alpha] over opaque [bottom], the way a tinted panel
/// composites onto the card behind it.
Color _over(Color top, double alpha, Color bottom) => Color.from(
  alpha: 1,
  red: top.r * alpha + bottom.r * (1 - alpha),
  green: top.g * alpha + bottom.g * (1 - alpha),
  blue: top.b * alpha + bottom.b * (1 - alpha),
);

const _aaText = 4.5;
const _aaGraphic = 3.0;

void main() {
  for (final (mode, p) in [('light', V3Palette.light), ('dark', V3Palette.dark)]) {
    // Every ground a colored label can legitimately sit on.
    final grounds = <String, Color>{
      'surface': p.surface,
      'canvas': p.canvas,
      'surfaceRaised': p.surfaceRaised,
      // Error banners paint the semantic color at 10-12% behind their own text.
      'warning@12% on surface': _over(p.warning, 0.12, p.surface),
      'danger@12% on surface': _over(p.danger, 0.12, p.surface),
      'success@12% on surface': _over(p.success, 0.12, p.surface),
    };

    final inks = <String, Color>{
      'lycheeInk': p.lycheeInk,
      'successInk': p.successInk,
      'warningInk': p.warningInk,
      'dangerInk': p.dangerInk,
      'inkMuted': p.inkMuted,
    };

    group('$mode text contrast', () {
      for (final ink in inks.entries) {
        test('${ink.key} clears AA on every ground', () {
          for (final ground in grounds.entries) {
            final ratio = _contrast(ink.value, ground.value);
            expect(
              ratio,
              greaterThanOrEqualTo(_aaText),
              reason:
                  '${ink.key} on ${ground.key} is '
                  '${ratio.toStringAsFixed(2)}:1, below the $_aaText:1 WCAG AA '
                  'minimum for text. Darken the token.',
            );
          }
        });
      }
    });

    group('$mode graphic contrast', () {
      // Icons and fills only owe WCAG 1.4.11's 3:1 — this is what lets the
      // brighter base colors stay in the design.
      final graphics = <String, Color>{
        'lychee': p.lychee,
        'success': p.success,
        'warning': p.warning,
        'danger': p.danger,
      };
      for (final g in graphics.entries) {
        test('${g.key} clears AA as a graphic', () {
          for (final ground in {
            'surface': p.surface,
            'canvas': p.canvas,
          }.entries) {
            final ratio = _contrast(g.value, ground.value);
            expect(
              ratio,
              greaterThanOrEqualTo(_aaGraphic),
              reason:
                  '${g.key} on ${ground.key} is ${ratio.toStringAsFixed(2)}:1, '
                  'below the $_aaGraphic:1 minimum for icons and UI shapes.',
            );
          }
        });
      }
    });

  }

  test('light-mode inks are darker than the semantic fills they replace', () {
    for (final pair in [
      (V3Palette.light.lycheeInk, V3Palette.light.lychee),
      (V3Palette.light.successInk, V3Palette.light.success),
      (V3Palette.light.warningInk, V3Palette.light.warning),
      (V3Palette.light.dangerInk, V3Palette.light.danger),
    ]) {
      expect(
        _luminance(pair.$1),
        lessThan(_luminance(pair.$2)),
        reason: 'light-mode inks must be darker than their fill counterparts',
      );
    }
  });
}

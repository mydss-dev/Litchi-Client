import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

// WCAG relative luminance, using the exact rendered palette tokens.
double _luminance(Color color) {
  double channel(double v) => v <= 0.04045
      ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

Color _over(Color foreground, double alpha, Color background) => Color.from(
  alpha: 1,
  red: foreground.r * alpha + background.r * (1 - alpha),
  green: foreground.g * alpha + background.g * (1 - alpha),
  blue: foreground.b * alpha + background.b * (1 - alpha),
);

void main() {
  for (final (mode, p) in [
    ('light', V3Palette.light),
    ('dark', V3Palette.dark),
  ]) {
    test('$mode: lime selection declares a dark, readable foreground', () {
      final theme = mode == 'light' ? V3Theme.light() : V3Theme.dark();
      expect(theme.colorScheme.secondary, p.citrus);
      expect(theme.colorScheme.onSecondary, p.night);
      expect(_contrast(theme.colorScheme.onSecondary, p.citrus),
        greaterThanOrEqualTo(4.5));
      // White text is not a safe default on this green selection fill.
      expect(_contrast(Colors.white, p.citrus), lessThan(4.5));
    });

    test('$mode: selected green labels remain readable on all tinted panels', () {
      for (final background in [p.surface, p.hero, p.surfaceRaised]) {
        final selectedFill = _over(p.success, .12, background);
        expect(_contrast(p.successInk, selectedFill),
          greaterThanOrEqualTo(4.5));
      }
    });

    test('$mode: selected chips declare safe foregrounds and backgrounds', () {
      final chip = (mode == 'light' ? V3Theme.light() : V3Theme.dark())
          .chipTheme;
      expect(chip.selectedColor, isNotNull);
      expect(chip.secondaryLabelStyle?.color, isNotNull);
      expect(_contrast(chip.secondaryLabelStyle!.color!, chip.selectedColor!),
        greaterThanOrEqualTo(4.5));
    });
  }
}

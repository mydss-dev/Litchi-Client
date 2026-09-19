import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

// WCAG relative luminance using the exact palette tokens.
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
    final theme = mode == 'light' ? V3Theme.light() : V3Theme.dark();

    test('$mode: Material secondary selection uses lychee, not lime', () {
      expect(theme.colorScheme.secondary, p.lychee);
      expect(theme.colorScheme.secondary, isNot(p.citrus));
      expect(theme.colorScheme.onSecondary, p.night);
      expect(_contrast(theme.colorScheme.onSecondary, p.lychee),
        greaterThanOrEqualTo(4.5));
    });

    test('$mode: segmented control matches plan-cycle selected skin', () {
      final style = theme.segmentedButtonTheme.style!;
      final selected = {WidgetState.selected};
      final unselected = <WidgetState>{};
      expect(style.backgroundColor!.resolve(selected), p.lycheeSoft);
      expect(style.foregroundColor!.resolve(selected), p.lycheeInk);
      expect(style.side!.resolve(selected)!.color, p.lychee);
      expect(style.backgroundColor!.resolve(unselected), p.surfaceRaised);
      expect(style.foregroundColor!.resolve(unselected), p.ink);
      expect(_contrast(p.lycheeInk, p.lycheeSoft),
        greaterThanOrEqualTo(4.5));
    });

    test('$mode: chip selection uses accessible lychee foreground and fill', () {
      final chip = theme.chipTheme;
      expect(chip.selectedColor, p.lycheeSoft);
      expect(chip.secondaryLabelStyle?.color, p.lycheeInk);
      expect(chip.checkmarkColor, p.lycheeInk);
      expect(_contrast(chip.secondaryLabelStyle!.color!, chip.selectedColor!),
        greaterThanOrEqualTo(4.5));
    });

    test('$mode: genuine success labels remain readable on tinted panels', () {
      for (final background in [p.surface, p.hero, p.surfaceRaised]) {
        final statusFill = _over(p.success, .12, background);
        expect(_contrast(p.successInk, statusFill),
          greaterThanOrEqualTo(4.5));
      }
    });
  }
}

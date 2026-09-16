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
  for (final (mode, p) in [
    ('light', V3Palette.light),
    ('dark', V3Palette.dark),
  ]) {
    // Every ground a colored label can legitimately sit on.
    final grounds = <String, Color>{
      'surface': p.surface,
      'canvas': p.canvas,
      'surfaceRaised': p.surfaceRaised,
      // The large panels (connect workspace, login brand block, rail, wallet
      // total) paint `hero` and write the muted inks straight onto it.
      'hero': p.hero,
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
      //
      // The grounds below are the ones an icon is actually drawn on, read off
      // the call sites: `hero` (the connect workspace, the traffic quota panel,
      // the boot progress bar), `surfaceRaised` (the icon tiles in the invite
      // and traffic rows), `lycheeSoft` (a chosen row) and `surface` (a card).
      // `canvas` is not among them: nothing paints a bare accent glyph on the
      // page ground, because every icon in this UI sits inside a panel or a
      // tile. Asserting it there was checking a combination the app never
      // produces, while the tinted grounds it *does* use went unchecked — which
      // is how a light-mode background got darker than the accents could
      // survive without this test noticing.
      final grounds = <String, Color>{
        'surface': p.surface,
        'surfaceRaised': p.surfaceRaised,
        'hero': p.hero,
        'lycheeSoft': p.lycheeSoft,
      };

      // What is drawn *on* those grounds is the Ink variant, not the base fill:
      // the base colors are tuned as large fills with white on top, and read as
      // a smudge once the ground behind them is tinted. The rail already did
      // this for its chosen row before the rest of the app had a reason to.
      final graphics = <String, Color>{
        'lycheeInk': p.lycheeInk,
        'successInk': p.successInk,
        'warningInk': p.warningInk,
        'dangerInk': p.dangerInk,
      };
      for (final g in graphics.entries) {
        test('${g.key} clears AA as a graphic on every ground', () {
          for (final ground in grounds.entries) {
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

      // A chosen row's soft fill is light enough to be a ground, so the base
      // lychee is checked where it is still legitimate: as a fill on a card,
      // which is the one place it carries white content instead of being a
      // glyph that has to be told apart from what is behind it.
      test('the base fills still clear AA on the card they are filled on', () {
        for (final fill in {
          'lychee': p.lychee,
          'success': p.success,
          'warning': p.warning,
          'danger': p.danger,
        }.entries) {
          final ratio = _contrast(fill.value, p.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(_aaGraphic),
            reason:
                '${fill.key} on surface is ${ratio.toStringAsFixed(2)}:1, below '
                'the $_aaGraphic:1 minimum for icons and UI shapes.',
          );
        }
      });
    });
  }

  // The hero panels used to be near-black in both modes with hardcoded white
  // text. Every one of them now paints `hero` and writes `ink` on top, so that
  // pairing carries body copy and owes the full AA ratio in both modes.
  test('ink on hero clears AA in both modes', () {
    for (final (mode, p) in [
      ('light', V3Palette.light),
      ('dark', V3Palette.dark),
    ]) {
      final ratio = _contrast(p.ink, p.hero);
      expect(
        ratio,
        greaterThanOrEqualTo(_aaText),
        reason:
            '$mode ink on hero is ${ratio.toStringAsFixed(2)}:1, below the '
            '$_aaText:1 WCAG AA minimum for text.',
      );
    }
  });

  // The reported bug: picking 月付/季付 in the payment dialog left the label on
  // Material's own `secondaryContainer`, which is a pale lilac both label
  // colours disappear into. The theme now supplies the pair, so the theme is
  // what this asserts — every selectable chip in the app inherits it.
  test('theme chips keep their labels legible in both states', () {
    for (final (mode, theme) in [
      ('light', V3Theme.light()),
      ('dark', V3Theme.dark()),
    ]) {
      final chip = theme.chipTheme;
      final pairs = <String, (Color?, Color?)>{
        'chosen': (chip.secondaryLabelStyle?.color, chip.selectedColor),
        'unchosen': (chip.labelStyle?.color, chip.backgroundColor),
        'checkmark': (chip.checkmarkColor, chip.selectedColor),
      };
      for (final entry in pairs.entries) {
        final (foreground, background) = entry.value;
        expect(
          foreground,
          isNotNull,
          reason: '$mode ${entry.key} chip has no foreground colour',
        );
        expect(
          background,
          isNotNull,
          reason: '$mode ${entry.key} chip has no background colour',
        );
        final ratio = _contrast(foreground!, background!);
        final floor = entry.key == 'checkmark' ? _aaGraphic : _aaText;
        expect(
          ratio,
          greaterThanOrEqualTo(floor),
          reason:
              '$mode ${entry.key} chip is ${ratio.toStringAsFixed(2)}:1, below '
              'the $floor:1 minimum.',
        );
      }
    }
  });

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

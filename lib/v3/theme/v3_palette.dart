import 'package:flutter/material.dart';

/// Litchi's visual language: editorial black, lychee red, and citrus signal.
/// Light and dark palettes are composed independently, not simply inverted.
@immutable
class V3Palette {
  const V3Palette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.night,
    required this.hero,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.lychee,
    required this.lycheeSoft,
    required this.citrus,
    required this.aqua,
    required this.success,
    required this.warning,
    required this.danger,
    required this.lycheeInk,
    required this.successInk,
    required this.warningInk,
    required this.dangerInk,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;

  /// Background for the large "hero" panels — the connect workspace, the login
  /// brand block, the sidebar.
  ///
  /// These used to be [night], which is near-black in *both* modes and turned
  /// every one of them into a black slab on an otherwise light screen. [night]
  /// is now only a *foreground* colour (something drawn on top of [citrus]);
  /// this is the surface behind it.
  final Color hero;
  final Color night;
  final Color ink;
  final Color inkMuted;
  final Color line;
  final Color lychee;
  final Color lycheeSoft;
  final Color citrus;
  final Color aqua;
  final Color success;
  final Color warning;
  final Color danger;

  /// Text-safe variants of the semantic colors.
  ///
  /// The four colors above are tuned as fills and icons: on a light ground they
  /// sit between 3.2:1 and 4.8:1, which clears the 3:1 WCAG asks of graphical
  /// objects but not the 4.5:1 it asks of body text. Small colored labels and
  /// error messages therefore use these darker inks, which clear 4.5:1 against
  /// every light surface. Dark mode already exceeds the ratio, so there the inks
  /// are simply the base colors.
  final Color lycheeInk;
  final Color successInk;
  final Color warningInk;
  final Color dangerInk;

  static const light = V3Palette(
    // Four tiers, darkest to lightest: canvas → hero → surfaceRaised → surface.
    //
    // Light mode used to run canvas #F3F4F0 under surface #FFFFFF, which is a
    // 3% difference — the background was there, but nothing on screen showed
    // it, so every page read as one flat white sheet with no depth. Dark mode
    // never had that problem (canvas #0C1010 and card #151B1A are obvious
    // steps), so these four are spaced to mirror it: a sage-green ground, a
    // near-white card sitting clearly above it, and a hero panel a shade below
    // the ground rather than above it, which is the direction dark mode uses
    // for its own hero.
    //
    // Pure white no longer appears in light mode at all. The one exception is
    // the QR pad in the payment flow, which scanners want white and which
    // therefore hard-codes it rather than reading a token.
    canvas: Color(0xFFE7EBE3),
    surface: Color(0xFFFBFCF9),
    surfaceRaised: Color(0xFFF0F2EC),
    hero: Color(0xFFDFE3DA),
    night: Color(0xFF121515),
    ink: Color(0xFF121515),
    // Darkened from #68716F (4.17:1 on `surfaceRaised`, below AA for the
    // segmented-control labels that sit on that track) and again from #636B69
    // when `hero` darkened underneath it — see `hero` above.
    inkMuted: Color(0xFF5C6462),
    line: Color(0xFFCBD2CB),
    lychee: Color(0xFFF25472),
    lycheeSoft: Color(0xFFFFE3E8),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF70D7D5),
    success: Color(0xFF249A6A),
    // Darkened from #C68122, which was 2.90:1 on `canvas` — below the 3:1 WCAG
    // asks of an icon or UI shape drawn on that ground.
    warning: Color(0xFFBA771C),
    danger: Color(0xFFCC3F57),
    // Keep text safe even on a green-tinted hero: #177045 only reached 4.18:1
    // after the 12% success tint was composited onto the darker hero surface.
    lycheeInk: Color(0xFFB32747),
    successInk: Color(0xFF11613A),
    warningInk: Color(0xFF8A5000),
    dangerInk: Color(0xFFB02E45),
  );

  static const dark = V3Palette(
    canvas: Color(0xFF0C1010),
    surface: Color(0xFF151B1A),
    surfaceRaised: Color(0xFF202826),
    // Dark mode keeps the near-black it always had; only light mode moves.
    hero: Color(0xFF080B0A),
    night: Color(0xFF080B0A),
    ink: Color(0xFFF0F5F0),
    inkMuted: Color(0xFF9BA8A3),
    line: Color(0xFF2B3834),
    lychee: Color(0xFFFF6683),
    lycheeSoft: Color(0xFF3A2027),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF79E0DC),
    success: Color(0xFF57D39A),
    warning: Color(0xFFF1BD59),
    danger: Color(0xFFFF7188),
    lycheeInk: Color(0xFFFF6683),
    successInk: Color(0xFF57D39A),
    warningInk: Color(0xFFF1BD59),
    dangerInk: Color(0xFFFF7188),
  );

  static V3Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

class V3Theme {
  const V3Theme._();

  static ThemeData light() => _build(Brightness.light, V3Palette.light);

  static ThemeData dark() => _build(Brightness.dark, V3Palette.dark);

  static ThemeData _build(Brightness brightness, V3Palette p) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.lychee,
      onPrimary: Colors.white,
      secondary: p.citrus,
      // Ink becomes near-white in dark mode. A bright lime selection must
      // retain the intentionally dark foreground in *both* appearances.
      onSecondary: p.night,
      error: p.danger,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.ink,
      outline: p.line,
      surfaceContainerHighest: p.surfaceRaised,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.canvas,
      fontFamily: 'Segoe UI',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          height: 1.05,
          fontWeight: FontWeight.w800,
          color: p.ink,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: p.ink,
        ),
        bodyLarge: TextStyle(fontSize: 14, height: 1.45, color: p.ink),
        bodyMedium: TextStyle(fontSize: 13, height: 1.4, color: p.ink),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: p.inkMuted),
        labelLarge: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: p.inkMuted,
        ),
      ),
      dividerColor: p.line,
      // Material's expanding splash reads as too loud against this much
      // whitespace, so it stays off — but a press still has to be visible.
      // The palette spends colour on state (selected, connected) and not on the
      // moment of the tap, and with the highlight transparent as well every
      // IconButton, chip and hub row was silent. A flat tint is the quiet
      // version of the same feedback.
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.ink.withValues(alpha: 0.06),
      // Every ChoiceChip in the app was falling through to Material's defaults,
      // which paint the chosen chip in `secondaryContainer` — a lilac that
      // appears nowhere else in this palette — under `onSecondaryContainer`
      // text at about 2.4:1. The subscription-cycle and payment-method pickers
      // were, literally, unreadable. Selection speaks the app's own colour
      // instead: a soft lychee fill, lychee ink for the label (4.9:1 on that
      // fill), and the checkmark that says which one is on.
      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.lycheeSoft,
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: p.lycheeInk,
        ),
        checkmarkColor: p.lycheeInk,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceRaised,
        hintStyle: TextStyle(color: p.inkMuted, fontSize: 13),
        prefixIconColor: p.inkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.lychee, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(color: p.surface, fontSize: 11),
      ),
    );
  }
}

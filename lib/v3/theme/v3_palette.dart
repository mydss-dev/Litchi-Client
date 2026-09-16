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
    canvas: Color(0xFFF3F4F0),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE8EBE5),
    night: Color(0xFF121515),
    ink: Color(0xFF121515),
    // Darkened from #68716F, which was only 4.17:1 on `surfaceRaised` — below
    // AA for the segmented-control labels that sit on that track.
    inkMuted: Color(0xFF636B69),
    line: Color(0xFFD8DEDA),
    lychee: Color(0xFFF25472),
    lycheeSoft: Color(0xFFFFE3E8),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF70D7D5),
    success: Color(0xFF249A6A),
    // Darkened from #C68122, which was 2.90:1 on `canvas` — below the 3:1 WCAG
    // asks of an icon or UI shape drawn on that ground.
    warning: Color(0xFFBA771C),
    danger: Color(0xFFCC3F57),
    lycheeInk: Color(0xFFBE2B4E),
    successInk: Color(0xFF177045),
    warningInk: Color(0xFF9A5A00),
    dangerInk: Color(0xFFB02E45),
  );

  static const dark = V3Palette(
    canvas: Color(0xFF0C1010),
    surface: Color(0xFF151B1A),
    surfaceRaised: Color(0xFF202826),
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
      onSecondary: p.ink,
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

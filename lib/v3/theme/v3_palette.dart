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

  static const light = V3Palette(
    canvas: Color(0xFFF3F4F0),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE8EBE5),
    night: Color(0xFF121515),
    ink: Color(0xFF121515),
    inkMuted: Color(0xFF68716F),
    line: Color(0xFFD8DEDA),
    lychee: Color(0xFFF25472),
    lycheeSoft: Color(0xFFFFE3E8),
    citrus: Color(0xFFD7F267),
    aqua: Color(0xFF70D7D5),
    success: Color(0xFF249A6A),
    warning: Color(0xFFC68122),
    danger: Color(0xFFCC3F57),
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
        bodySmall: TextStyle(fontSize: 11, height: 1.35, color: p.inkMuted),
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
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
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

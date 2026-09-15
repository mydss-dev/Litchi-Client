import 'package:flutter/material.dart';

@immutable
class V3Palette {
  const V3Palette({
    required this.canvas,
    required this.panel,
    required this.panelStrong,
    required this.rail,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.cyan,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color panel;
  final Color panelStrong;
  final Color rail;
  final Color text;
  final Color textMuted;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color cyan;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = V3Palette(
    canvas: Color(0xFFF7F6FB),
    panel: Color(0xFFFFFFFF),
    panelStrong: Color(0xFFF1EFF8),
    rail: Color(0xFF17151F),
    text: Color(0xFF17151F),
    textMuted: Color(0xFF716D7E),
    border: Color(0xFFE6E2EC),
    accent: Color(0xFFEE5E91),
    accentSoft: Color(0xFFFFE6EF),
    cyan: Color(0xFF4FC6D8),
    success: Color(0xFF34B27B),
    warning: Color(0xFFE4A73B),
    danger: Color(0xFFD84C65),
  );

  static const dark = V3Palette(
    canvas: Color(0xFF0D0B12),
    panel: Color(0xFF15121C),
    panelStrong: Color(0xFF1D1926),
    rail: Color(0xFF09080D),
    text: Color(0xFFF4F0F6),
    textMuted: Color(0xFF9F98AA),
    border: Color(0xFF2A2532),
    accent: Color(0xFFFF6E9F),
    accentSoft: Color(0xFF3A1D2A),
    cyan: Color(0xFF62D6E5),
    success: Color(0xFF53D69A),
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
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: brightness,
        surface: p.panel,
      ),
      fontFamily: 'Segoe UI',
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: p.text,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: p.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: p.text,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: p.text,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w500,
          color: p.text,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          height: 1.4,
          fontWeight: FontWeight.w500,
          color: p.textMuted,
        ),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: p.border,
    );
  }
}

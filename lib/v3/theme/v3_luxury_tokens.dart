import 'package:flutter/material.dart';

/// Champagne Gold design system, held separately from the legacy palette while
/// screens migrate. Existing V3Palette semantics remain source compatible.
///
/// Gold is for actions and selection. Success green is for a validated status,
/// never a highlighted tab, chip or button.
@immutable
class V3LuxuryTokens extends ThemeExtension<V3LuxuryTokens> {
  const V3LuxuryTokens({
    required this.canvas,
    required this.canvasDeep,
    required this.surface,
    required this.surfaceStrong,
    required this.surfaceSolid,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.lineStrong,
    required this.glassBorder,
    required this.gold,
    required this.goldTint,
    required this.orbFace,
    required this.onGold,
    required this.aqua,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color canvasDeep;
  final Color surface;
  final Color surfaceStrong;
  final Color surfaceSolid;
  final Color ink;
  final Color ink2;
  final Color ink3;
  final Color line;
  final Color lineStrong;
  final Color glassBorder;
  final Color gold;
  final Color goldTint;
  final Color orbFace;
  final Color onGold;
  final Color aqua;
  final Color success;
  final Color warning;
  final Color danger;

  static V3LuxuryTokens of(BuildContext context) =>
      Theme.of(context).extension<V3LuxuryTokens>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  static const dark = V3LuxuryTokens(
    canvas: Color(0xFF0A0D0F),
    canvasDeep: Color(0xFF050808),
    surface: Color(0x0FFFFFFF),
    surfaceStrong: Color(0x1AFFFFFF),
    surfaceSolid: Color(0xFF14171A),
    ink: Color(0xFFF5F2ED),
    ink2: Color(0xFFA3A3A6),
    ink3: Color(0xFF6E7075),
    line: Color(0x1AFFFFFF),
    lineStrong: Color(0x33FFFFFF),
    glassBorder: Color(0x2EFFFFFF),
    gold: Color(0xFFE8C269),
    goldTint: Color(0x24E8C269),
    orbFace: Color(0xFFE8C269),
    onGold: Color(0xFF14120D),
    aqua: Color(0xFF9ED9D6),
    success: Color(0xFF7DD9A6),
    warning: Color(0xFFD79752),
    danger: Color(0xFFE07866),
  );

  static const light = V3LuxuryTokens(
    canvas: Color(0xFFF2F0EB),
    canvasDeep: Color(0xFFE5E0D9),
    surface: Color(0xBFFFFFFF),
    surfaceStrong: Color(0xF5FFFFFF),
    surfaceSolid: Color(0xFFFCFCFA),
    ink: Color(0xFF17171A),
    ink2: Color(0xFF5C5E63),
    ink3: Color(0xFF919499),
    line: Color(0x1A17171A),
    lineStrong: Color(0x2917171A),
    glassBorder: Color(0xD9FFFFFF),
    gold: Color(0xFFA88033),
    goldTint: Color(0xFFF5EDD6),
    orbFace: Color(0xFF171C21),
    onGold: Color(0xFFFFFFFF),
    aqua: Color(0xFF29807D),
    success: Color(0xFF178759),
    warning: Color(0xFF9D6325),
    danger: Color(0xFFBF422B),
  );

  @override
  V3LuxuryTokens copyWith({
    Color? canvas,
    Color? canvasDeep,
    Color? surface,
    Color? surfaceStrong,
    Color? surfaceSolid,
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? line,
    Color? lineStrong,
    Color? glassBorder,
    Color? gold,
    Color? goldTint,
    Color? orbFace,
    Color? onGold,
    Color? aqua,
    Color? success,
    Color? warning,
    Color? danger,
  }) => V3LuxuryTokens(
    canvas: canvas ?? this.canvas,
    canvasDeep: canvasDeep ?? this.canvasDeep,
    surface: surface ?? this.surface,
    surfaceStrong: surfaceStrong ?? this.surfaceStrong,
    surfaceSolid: surfaceSolid ?? this.surfaceSolid,
    ink: ink ?? this.ink,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    gold: gold ?? this.gold,
    goldTint: goldTint ?? this.goldTint,
    orbFace: orbFace ?? this.orbFace,
    onGold: onGold ?? this.onGold,
    aqua: aqua ?? this.aqua,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  @override
  V3LuxuryTokens lerp(ThemeExtension<V3LuxuryTokens>? other, double t) {
    if (other is! V3LuxuryTokens) return this;
    return V3LuxuryTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      canvasDeep: Color.lerp(canvasDeep, other.canvasDeep, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      surfaceSolid: Color.lerp(surfaceSolid, other.surfaceSolid, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      goldTint: Color.lerp(goldTint, other.goldTint, t)!,
      orbFace: Color.lerp(orbFace, other.orbFace, t)!,
      onGold: Color.lerp(onGold, other.onGold, t)!,
      aqua: Color.lerp(aqua, other.aqua, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Component geometry. Keep legacy V3Radius unchanged until all seven screens
/// are migrated; newly migrated components use these tiers immediately.
abstract final class V3LuxuryRadius {
  static const double tag = 8;
  static const double control = 18;
  static const double input = 21;
  static const double card = 24;
  static const double hero = 30;
  static const double pill = 999;
}

abstract final class V3LuxurySpacing {
  static const double pageHorizontal = 20;
  static const double unit4 = 4;
  static const double unit6 = 6;
  static const double unit8 = 8;
  static const double unit10 = 10;
  static const double unit14 = 14;
  static const double unit18 = 18;
  static const double unit24 = 24;
}

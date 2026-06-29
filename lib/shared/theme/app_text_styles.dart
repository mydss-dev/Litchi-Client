import 'package:flutter/widgets.dart';

/// Typography tokens (§6.3).
///
/// Styles carry size/weight/height only — color is applied at the call site
/// from [AppColors] so the same style works in light and dark.
class AppTextStyles {
  AppTextStyles._();

  /// Font priority per spec. We don't bundle Inter, so the system stack
  /// (Segoe UI / YaHei on Windows) resolves the fallbacks.
  static const List<String> fontFamilyFallback = [
    'Inter',
    'SF Pro Display',
    'SF Pro Text',
    'Segoe UI',
    'Segoe UI Emoji',
    'HarmonyOS Sans SC',
    'Microsoft YaHei',
    'PingFang SC',
    'sans-serif',
  ];

  static const TextStyle _base = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    height: 1.2,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle authTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  /// Large numeric display (20–34). Pass [fontSize] for the specific context.
  static TextStyle largeNumber({double fontSize = 28}) => TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle badge = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle menu = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle button = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle input = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  /// Auth subtitle (13 / 400).
  static const TextStyle authSubtitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );

  /// Fallback base style for the MaterialApp text theme.
  static TextStyle get base => _base;
}

import 'package:flutter/widgets.dart';

/// Typography tokens shared across Windows, macOS and compact layouts.
///
/// Styles carry size/weight/height only — color is applied at the call site
/// from AppColors so the same style works in light and dark themes.
class AppTextStyles {
  AppTextStyles._();

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
    height: 1.25,
  );

  static const TextStyle heroTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.15,
  );

  static const TextStyle authTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Large numeric display. Pass [fontSize] for the specific context.
  static TextStyle largeNumber({double fontSize = 28}) => TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
    height: 1.1,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle body = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  static const TextStyle caption = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle badge = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle menu = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle button = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const TextStyle input = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.25,
  );

  static const TextStyle authSubtitle = TextStyle(
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
  );

  static TextStyle get base => _base;
}

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Elevation tokens (§6.6).
///
/// Card/soft shadows derive their color from the active theme so they read
/// correctly in both light and dark. The brand-emphasis shadow is fixed.
class AppShadows {
  AppShadows._();

  /// Standard card: 0 8px 24px shadow.
  static List<BoxShadow> card(AppColors c) => [
    BoxShadow(color: c.shadow, offset: const Offset(0, 8), blurRadius: 24),
  ];

  /// Lighter elevation: 0 6px 16px (slightly softer than [card]).
  static List<BoxShadow> soft(AppColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: c.shadow.a * 0.7),
      offset: const Offset(0, 6),
      blurRadius: 16,
    ),
  ];

  /// Outer window shell shadow: 0 16px 40px rgba(15,23,42,0.12).
  static const List<BoxShadow> window = [
    BoxShadow(color: Color(0x1F0F172A), offset: Offset(0, 16), blurRadius: 40),
  ];

  /// Brand-emphasis glow: 0 12px 28px rgba(37,99,235,0.25).
  static const List<BoxShadow> brand = [
    BoxShadow(color: Color(0x402563EB), offset: Offset(0, 12), blurRadius: 28),
  ];

  /// Power-button glow used on the dashboard hero (same as [brand] but kept
  /// as a named token for clarity at call sites).
  static const List<BoxShadow> powerButton = [
    BoxShadow(color: Color(0x402563EB), offset: Offset(0, 12), blurRadius: 28),
  ];
}

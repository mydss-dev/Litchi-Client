import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Elevation tokens (§6.6).
///
/// Card/soft shadows derive their color from the active theme so they read
/// correctly in both light and dark. The brand-emphasis shadow is fixed.
class AppShadows {
  AppShadows._();

  /// Standard card: soft desktop elevation without a floating-card effect.
  static List<BoxShadow> card(AppColors c) => [
    BoxShadow(color: c.shadow, offset: const Offset(0, 6), blurRadius: 18),
  ];

  /// Lighter elevation for selected controls and compact floating surfaces.
  static List<BoxShadow> soft(AppColors c) => [
    BoxShadow(
      color: c.shadow.withValues(alpha: c.shadow.a * 0.7),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// Brand-emphasis glow used by the connection control only.
  static const List<BoxShadow> brand = [
    BoxShadow(color: Color(0x40E54865), offset: Offset(0, 12), blurRadius: 28),
  ];

  /// Power-button glow used on the dashboard hero.
  static const List<BoxShadow> powerButton = [
    BoxShadow(color: Color(0x40E54865), offset: Offset(0, 12), blurRadius: 28),
  ];
}

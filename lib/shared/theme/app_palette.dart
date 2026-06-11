import 'package:flutter/widgets.dart';

import '../config/app_config.dart';

/// Raw color values transcribed from the design spec (§6).
///
/// Brand gradient colors delegate to [BrandConfig] so they can be swapped at
/// build time via --dart-define. All other palette tokens remain const.
/// Prefer consuming semantic colors via [AppColors.of] in widgets.
class AppPalette {
  AppPalette._();

  // ---------------------------------------------------------------------------
  // Brand gradients — driven by BrandConfig (--dart-define overridable)
  // ---------------------------------------------------------------------------
  static Color get brandStart => AppConfig.brandStart;
  static Color get brandEnd   => AppConfig.brandEnd;

  static Color get authButtonStart => AppConfig.brandStart;
  static Color get authButtonEnd   => AppConfig.brandEnd;

  static LinearGradient get brandGradient => AppConfig.brandGradient;

  // ---------------------------------------------------------------------------
  // Light theme (§6.1)
  // ---------------------------------------------------------------------------
  static const Color lightAppBg = Color(0xFFF8FAFC);
  static const Color lightSidebarBg = Color(0xFFFFFFFF);
  static const Color lightCardBg = Color(0xFFFFFFFF);
  static const Color lightSurfaceMuted = Color(0xFFF1F5F9);

  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightSidebarBorder = Color(0xFFE5EAF2);
  static const Color lightSoftBorder = Color(0xFFEEF2F7);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  static const Color lightIconDefault = Color(0xFF64748B);
  static const Color lightIconMuted = Color(0xFF94A3B8);

  static Color get lightPrimary => AppConfig.brandStart;
  static const Color lightPrimaryHover = Color(0xFF1D4ED8);
  static const Color lightPrimarySoft = Color(0xFFEFF6FF);

  static Color get lightSecondary => AppConfig.brandEnd;
  static const Color lightSecondarySoft = Color(0xFFF5F3FF);

  static const Color lightSuccess = Color(0xFF22C55E);
  static const Color lightWarning = Color(0xFFF59E0B);
  static const Color lightDanger = Color(0xFFEF4444);
  static const Color lightDangerSoft = Color(0xFFFEE2E2);

  static const Color lightPremiumBadgeBg = Color(0xFFFEF3C7);
  static const Color lightPremiumBadgeText = Color(0xFF92400E);

  static const Color lightShadow = Color(0x0F0F172A); // rgba(15,23,42,0.06)

  // ---------------------------------------------------------------------------
  // Dark theme (§6.2)
  // ---------------------------------------------------------------------------
  static const Color darkAppBg = Color(0xFF0F172A);
  static const Color darkSidebarBg = Color(0xFF111827);
  static const Color darkCardBg = Color(0xFF1E293B);
  static const Color darkSurfaceMuted = Color(0xFF273449);

  static const Color darkBorder = Color(0xFF334155);
  static const Color darkSidebarBorder = Color(0xFF263445);
  static const Color darkSoftBorder = Color(0xFF263445);

  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  static const Color darkIconDefault = Color(0xFFCBD5E1);
  static const Color darkIconMuted = Color(0xFF94A3B8);

  static Color get darkPrimary => AppConfig.brandStart;
  static const Color darkPrimaryHover = Color(0xFF2563EB);
  static const Color darkPrimarySoft = Color(0x293B82F6); // rgba(59,130,246,0.16)

  static Color get darkSecondary => AppConfig.brandEnd;
  static const Color darkSecondarySoft = Color(0x298B5CF6); // rgba(139,92,246,0.16)

  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkDanger = Color(0xFFEF4444);
  static const Color darkDangerSoft = Color(0x29EF4444);

  static const Color darkPremiumBadgeBg = Color(0x29F59E0B); // rgba(245,158,11,0.16)
  static const Color darkPremiumBadgeText = Color(0xFFFBBF24);

  static const Color darkShadow = Color(0x59000000); // rgba(0,0,0,0.35)
}

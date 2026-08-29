import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Semantic, theme-aware colors exposed as a [ThemeExtension].
///
/// Access in widgets via `AppColors.of(context)`. Switching [ThemeMode]
/// swaps the whole set, so widgets never branch on brightness themselves.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.appBg,
    required this.cardBg,
    required this.surfaceMuted,
    required this.border,
    required this.softBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.iconDefault,
    required this.iconMuted,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.secondary,
    required this.secondarySoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerSoft,
    required this.premiumBadgeBg,
    required this.premiumBadgeText,
    required this.shadow,
  });

  final Color appBg;
  final Color cardBg;
  final Color surfaceMuted;

  final Color border;
  final Color softBorder;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color iconDefault;
  final Color iconMuted;

  final Color primary;
  final Color primaryHover;
  final Color primarySoft;

  final Color secondary;
  final Color secondarySoft;

  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerSoft;

  final Color premiumBadgeBg;
  final Color premiumBadgeText;

  final Color shadow;

  /// Brand gradient is theme-independent.
  LinearGradient get brandGradient => AppPalette.brandGradient;

  /// Standard content-card surface used throughout the app.
  LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardBg, primarySoft],
  );

  static final AppColors light = AppColors(
    appBg: AppPalette.lightAppBg,
    cardBg: AppPalette.lightCardBg,
    surfaceMuted: AppPalette.lightSurfaceMuted,
    border: AppPalette.lightBorder,
    softBorder: AppPalette.lightSoftBorder,
    textPrimary: AppPalette.lightTextPrimary,
    textSecondary: AppPalette.lightTextSecondary,
    textMuted: AppPalette.lightTextMuted,
    iconDefault: AppPalette.lightIconDefault,
    iconMuted: AppPalette.lightIconMuted,
    primary: AppPalette.lightPrimary,
    primaryHover: AppPalette.lightPrimaryHover,
    primarySoft: AppPalette.lightPrimarySoft,
    secondary: AppPalette.lightSecondary,
    secondarySoft: AppPalette.lightSecondarySoft,
    success: AppPalette.lightSuccess,
    warning: AppPalette.lightWarning,
    danger: AppPalette.lightDanger,
    dangerSoft: AppPalette.lightDangerSoft,
    premiumBadgeBg: AppPalette.lightPremiumBadgeBg,
    premiumBadgeText: AppPalette.lightPremiumBadgeText,
    shadow: AppPalette.lightShadow,
  );

  static final AppColors dark = AppColors(
    appBg: AppPalette.darkAppBg,
    cardBg: AppPalette.darkCardBg,
    surfaceMuted: AppPalette.darkSurfaceMuted,
    border: AppPalette.darkBorder,
    softBorder: AppPalette.darkSoftBorder,
    textPrimary: AppPalette.darkTextPrimary,
    textSecondary: AppPalette.darkTextSecondary,
    textMuted: AppPalette.darkTextMuted,
    iconDefault: AppPalette.darkIconDefault,
    iconMuted: AppPalette.darkIconMuted,
    primary: AppPalette.darkPrimary,
    primaryHover: AppPalette.darkPrimaryHover,
    primarySoft: AppPalette.darkPrimarySoft,
    secondary: AppPalette.darkSecondary,
    secondarySoft: AppPalette.darkSecondarySoft,
    success: AppPalette.darkSuccess,
    warning: AppPalette.darkWarning,
    danger: AppPalette.darkDanger,
    dangerSoft: AppPalette.darkDangerSoft,
    premiumBadgeBg: AppPalette.darkPremiumBadgeBg,
    premiumBadgeText: AppPalette.darkPremiumBadgeText,
    shadow: AppPalette.darkShadow,
  );

  /// Convenience accessor; falls back to [light] if the extension is missing.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({
    Color? appBg,
    Color? cardBg,
    Color? surfaceMuted,
    Color? border,
    Color? softBorder,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? iconDefault,
    Color? iconMuted,
    Color? primary,
    Color? primaryHover,
    Color? primarySoft,
    Color? secondary,
    Color? secondarySoft,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerSoft,
    Color? premiumBadgeBg,
    Color? premiumBadgeText,
    Color? shadow,
  }) {
    return AppColors(
      appBg: appBg ?? this.appBg,
      cardBg: cardBg ?? this.cardBg,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      softBorder: softBorder ?? this.softBorder,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      iconDefault: iconDefault ?? this.iconDefault,
      iconMuted: iconMuted ?? this.iconMuted,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primarySoft: primarySoft ?? this.primarySoft,
      secondary: secondary ?? this.secondary,
      secondarySoft: secondarySoft ?? this.secondarySoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      premiumBadgeBg: premiumBadgeBg ?? this.premiumBadgeBg,
      premiumBadgeText: premiumBadgeText ?? this.premiumBadgeText,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      appBg: Color.lerp(appBg, other.appBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      softBorder: Color.lerp(softBorder, other.softBorder, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      iconDefault: Color.lerp(iconDefault, other.iconDefault, t)!,
      iconMuted: Color.lerp(iconMuted, other.iconMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondarySoft: Color.lerp(secondarySoft, other.secondarySoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      premiumBadgeBg: Color.lerp(premiumBadgeBg, other.premiumBadgeBg, t)!,
      premiumBadgeText: Color.lerp(
        premiumBadgeText,
        other.premiumBadgeText,
        t,
      )!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_text_styles.dart';

/// Builds the light/dark [ThemeData] for Litchi Client.
///
/// All product colors live in the [AppColors] extension; the base Material
/// theme is only configured enough to keep scaffold backgrounds and default
/// text colors on-brand (never Material blue — §3 rule 8).
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.appBg,
      canvasColor: c.appBg,
      colorScheme: base.colorScheme.copyWith(
        brightness: brightness,
        primary: c.primary,
        secondary: c.secondary,
        surface: c.cardBg,
        error: c.danger,
      ),
      // Brand gradient seed so any stray Material accents stay on-brand.
      primaryColor: AppPalette.brandStart,
      dividerColor: c.border,
      textTheme: _textTheme(base.textTheme, c),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static TextTheme _textTheme(TextTheme base, AppColors c) {
    return base
        .apply(
          fontFamilyFallback: AppTextStyles.fontFamilyFallback,
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        )
        .copyWith(
          bodyMedium: AppTextStyles.body.copyWith(color: c.textPrimary),
        );
  }
}

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_palette.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// Builds the light/dark ThemeData for Litchi Client.
///
/// Product colors live in AppColors. Material defaults are normalized here so
/// shared and native controls use the same desktop density, radius and focus
/// language across Windows and macOS.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );

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
      primaryColor: AppPalette.brandStart,
      dividerColor: c.border,
      focusColor: c.primary.withValues(alpha: 0.08),
      hoverColor: c.primary.withValues(alpha: 0.045),
      highlightColor: c.primary.withValues(alpha: 0.06),
      textTheme: _textTheme(base.textTheme, c),
      splashFactory: InkRipple.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: controlShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: controlShape,
          side: BorderSide(color: c.border),
          textStyle: AppTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: controlShape,
          textStyle: AppTextStyles.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(36),
          padding: const EdgeInsets.all(AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: AppTextStyles.caption.copyWith(color: c.cardBg),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.cardBg,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: c.softBorder),
        ),
      ),
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

import 'app_platform.dart';

enum AppControlSize { compact, regular }

/// Interaction geometry shared by Windows, macOS and touch-first platforms.
///
/// Layout width and input method are separate concerns: a wide Android device
/// still needs touch-safe targets, while a narrow desktop window keeps precise
/// pointer controls.
class AppControlMetrics {
  AppControlMetrics._();

  static const double pointerRegularHeight = 40;
  static const double touchRegularHeight = 48;
  static const double pointerCompactHeight = 34;
  static const double touchCompactHeight = 44;

  static const double pointerIconButtonExtent = 36;
  static const double touchIconButtonExtent = 48;

  static const double regularIconSize = 18;
  static const double compactIconSize = 16;

  static bool usesTouchFor(AppPlatformKind platform) => switch (platform) {
    AppPlatformKind.windows ||
    AppPlatformKind.macOS ||
    AppPlatformKind.linux => false,
    _ => true,
  };

  static double heightFor(
    AppPlatformKind platform, {
    AppControlSize size = AppControlSize.regular,
  }) {
    final touch = usesTouchFor(platform);
    return switch ((touch, size)) {
      (false, AppControlSize.compact) => pointerCompactHeight,
      (false, AppControlSize.regular) => pointerRegularHeight,
      (true, AppControlSize.compact) => touchCompactHeight,
      (true, AppControlSize.regular) => touchRegularHeight,
    };
  }

  static double get regularHeight => heightFor(AppPlatform.current);

  static double get compactHeight => heightFor(
    AppPlatform.current,
    size: AppControlSize.compact,
  );

  static double iconButtonExtentFor(AppPlatformKind platform) =>
      usesTouchFor(platform) ? touchIconButtonExtent : pointerIconButtonExtent;

  static double get iconButtonExtent => iconButtonExtentFor(AppPlatform.current);
}
import 'package:flutter/foundation.dart';

/// UI-facing platform identity.
///
/// Do not use this for proxy/core feature support. Business and native
/// capability decisions stay in CorePlatformSupport. This type exists only so
/// visual/layout code can describe native interaction differences without
/// importing dart:io throughout the widget tree.
enum AppPlatformKind { windows, macOS, android, linux, iOS, other }

class AppPlatform {
  AppPlatform._();

  static AppPlatformKind get current {
    if (kIsWeb) return AppPlatformKind.other;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => AppPlatformKind.windows,
      TargetPlatform.macOS => AppPlatformKind.macOS,
      TargetPlatform.android => AppPlatformKind.android,
      TargetPlatform.linux => AppPlatformKind.linux,
      TargetPlatform.iOS => AppPlatformKind.iOS,
      _ => AppPlatformKind.other,
    };
  }

  static bool get isDesktop => switch (current) {
    AppPlatformKind.windows ||
    AppPlatformKind.macOS ||
    AppPlatformKind.linux => true,
    _ => false,
  };

  static bool get isCompactPrimary => current == AppPlatformKind.android;

  static bool get usesPointer => isDesktop;
  static bool get usesTouch => !isDesktop;
}

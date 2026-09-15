import 'package:flutter/widgets.dart';

import 'app_layout.dart';
import 'app_platform.dart';

enum AppNavigationMode { sidebar, bottomBar }

enum AppWindowChrome { customDesktop, nativeMacOS, systemMobile }

/// Platform-to-shell contract for Litchi UI.
///
/// This describes presentation only. Native proxy/core capability checks must
/// continue to use CorePlatformSupport.
class AppShellSpec {
  AppShellSpec._();

  static AppNavigationMode navigationFor(AppPlatformKind platform) =>
      switch (platform) {
        AppPlatformKind.windows ||
        AppPlatformKind.macOS ||
        AppPlatformKind.linux => AppNavigationMode.sidebar,
        _ => AppNavigationMode.bottomBar,
      };

  static AppWindowChrome chromeFor(AppPlatformKind platform) =>
      switch (platform) {
        AppPlatformKind.windows || AppPlatformKind.linux =>
          AppWindowChrome.customDesktop,
        AppPlatformKind.macOS => AppWindowChrome.nativeMacOS,
        _ => AppWindowChrome.systemMobile,
      };

  static EdgeInsets pagePaddingFor(AppPlatformKind platform) =>
      navigationFor(platform) == AppNavigationMode.sidebar
      ? AppLayoutMetrics.desktopPagePadding
      : AppLayoutMetrics.compactPagePadding;

  static bool usesDesktopWindowSizing(AppPlatformKind platform) =>
      navigationFor(platform) == AppNavigationMode.sidebar;
}

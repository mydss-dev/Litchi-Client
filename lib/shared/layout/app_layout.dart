import 'package:flutter/widgets.dart';

import '../theme/app_breakpoints.dart';

/// Width-driven layout class shared by Windows, macOS and Android.
///
/// Platform identity and layout density are intentionally separate concerns:
/// a wide Android surface may use a wider feature arrangement while still
/// keeping touch-first interaction, and a narrow desktop window may stack
/// content without pretending to be a mobile platform.
enum AppLayoutClass { compact, medium, expanded }

/// Cross-platform geometry tokens for the application shell and page content.
///
/// Keep stable product geometry here instead of scattering width/padding magic
/// numbers throughout features. Native window lifecycle behavior remains owned
/// by AppShell / platform code.
class AppLayoutMetrics {
  AppLayoutMetrics._();

  // Desktop window target (Windows + macOS).
  static const Size desktopDefaultWindow = Size(900, 700);
  static const Size desktopMinimumWindow = Size(800, 600);
  static const double desktopSidebarWidth = 200;

  // Desktop authentication surface. Auth remains a fixed presentation window;
  // business/auth lifecycle still belongs to AppShell and AppController.
  static const double desktopAuthWindowWidth = 860;
  static const Size desktopAuthMinimumWindow = Size(760, 560);
  static const double desktopAuthLoginHeight = 620;
  static const double desktopAuthRegisterHeight = 760;
  static const double desktopAuthChangePasswordHeight = 660;
  static const double desktopAuthForgotPasswordHeight = 720;
  static const double desktopAuthFormMaxWidth = 420;
  static const int desktopAuthBrandFlex = 42;
  static const int desktopAuthFormFlex = 58;

  // Shell content padding.
  static const EdgeInsets desktopPagePadding = EdgeInsets.fromLTRB(
    24,
    20,
    24,
    24,
  );
  static const EdgeInsets compactPagePadding = EdgeInsets.fromLTRB(
    16,
    12,
    16,
    12,
  );

  // Shared component geometry.
  static const double sectionGap = 16;
  static const double denseGap = 8;
  static const double minTouchTarget = 48;
  static const double defaultContentMaxWidth = 1120;
  static const double mediumContentMaxWidth = 840;

  static AppLayoutClass classify(double width) {
    if (AppBreakpoints.isCompact(width)) return AppLayoutClass.compact;
    if (AppBreakpoints.isMedium(width)) return AppLayoutClass.medium;
    return AppLayoutClass.expanded;
  }

  static double contentMaxWidthFor(double width) => switch (classify(width)) {
    AppLayoutClass.compact => double.infinity,
    AppLayoutClass.medium => mediumContentMaxWidth,
    AppLayoutClass.expanded => defaultContentMaxWidth,
  };
}

@immutable
class AppLayoutSnapshot {
  const AppLayoutSnapshot({
    required this.width,
    required this.height,
    required this.layoutClass,
  });

  factory AppLayoutSnapshot.fromSize(Size size) => AppLayoutSnapshot(
    width: size.width,
    height: size.height,
    layoutClass: AppLayoutMetrics.classify(size.width),
  );

  final double width;
  final double height;
  final AppLayoutClass layoutClass;

  bool get isCompact => layoutClass == AppLayoutClass.compact;
  bool get isMedium => layoutClass == AppLayoutClass.medium;
  bool get isExpanded => layoutClass == AppLayoutClass.expanded;
}

extension AppLayoutContext on BuildContext {
  AppLayoutSnapshot get appLayout =>
      AppLayoutSnapshot.fromSize(MediaQuery.sizeOf(this));
}

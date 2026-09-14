import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/layout/app_layout.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';

void main() {
  group('AppLayoutMetrics', () {
    test('classifies compact, medium and expanded boundaries', () {
      expect(AppLayoutMetrics.classify(0), AppLayoutClass.compact);
      expect(AppLayoutMetrics.classify(599.9), AppLayoutClass.compact);
      expect(AppLayoutMetrics.classify(600), AppLayoutClass.medium);
      expect(AppLayoutMetrics.classify(899.9), AppLayoutClass.medium);
      expect(AppLayoutMetrics.classify(900), AppLayoutClass.expanded);
    });

    test('keeps frozen desktop shell geometry', () {
      expect(AppLayoutMetrics.desktopDefaultWindow.width, 900);
      expect(AppLayoutMetrics.desktopDefaultWindow.height, 700);
      expect(AppLayoutMetrics.desktopMinimumWindow.width, 800);
      expect(AppLayoutMetrics.desktopMinimumWindow.height, 600);
      expect(AppLayoutMetrics.desktopSidebarWidth, 200);
    });

    test('uses shared content caps by layout class', () {
      expect(AppLayoutMetrics.contentMaxWidthFor(500), double.infinity);
      expect(
        AppLayoutMetrics.contentMaxWidthFor(700),
        AppLayoutMetrics.mediumContentMaxWidth,
      );
      expect(
        AppLayoutMetrics.contentMaxWidthFor(1200),
        AppLayoutMetrics.defaultContentMaxWidth,
      );
    });
  });

  group('AppShellSpec', () {
    test('Windows and macOS use the shared desktop sidebar shell', () {
      expect(
        AppShellSpec.navigationFor(AppPlatformKind.windows),
        AppNavigationMode.sidebar,
      );
      expect(
        AppShellSpec.navigationFor(AppPlatformKind.macOS),
        AppNavigationMode.sidebar,
      );
    });

    test('Android uses the compact bottom navigation shell', () {
      expect(
        AppShellSpec.navigationFor(AppPlatformKind.android),
        AppNavigationMode.bottomBar,
      );
    });

    test('window chrome stays native where required', () {
      expect(
        AppShellSpec.chromeFor(AppPlatformKind.windows),
        AppWindowChrome.customDesktop,
      );
      expect(
        AppShellSpec.chromeFor(AppPlatformKind.macOS),
        AppWindowChrome.nativeMacOS,
      );
      expect(
        AppShellSpec.chromeFor(AppPlatformKind.android),
        AppWindowChrome.systemMobile,
      );
    });
  });
}

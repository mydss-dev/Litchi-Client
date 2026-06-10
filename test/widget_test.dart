import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';

void main() {
  test('AppController navigates between pages', () {
    final c = AppController();
    expect(c.page, AppPage.dashboard);
    c.goToPage(AppPage.nodes);
    expect(c.page, AppPage.nodes);
  });

  test('AppController logout resets auth state', () {
    final c = AppController();
    expect(c.isAuthenticated, isFalse);
    c.logout();
    expect(c.isAuthenticated, isFalse);
  });

  test('AppController toggles theme mode', () {
    final c = AppController();
    expect(c.isDark, isFalse);
    c.toggleDarkMode(true);
    expect(c.themeMode, ThemeMode.dark);
  });
}

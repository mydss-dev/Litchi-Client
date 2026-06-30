import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/node_selection_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('AppController persists the automatic update preference', () async {
    final c = AppController();

    c.setAutoUpdate(false);
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();

    expect(c.autoUpdate, isFalse);
    expect(prefs.getBool('auto_update'), isFalse);
  });

  test('AppController clearStartupMessage is a safe no-op when empty', () {
    final c = AppController();
    var notified = false;
    c.addListener(() => notified = true);

    c.clearStartupMessage();

    expect(c.startupMessage, isNull);
    expect(notified, isFalse);
  });

  test('AppController manual node selection updates visible node', () async {
    final c = AppController();
    const node = NodeModel(
      id: 'node-1',
      name: '香港 01',
      flag: '🇭🇰',
      latency: 80,
    );

    final error = await c.setCurrentNode(node);

    expect(error, isNull);
    expect(c.autoSelected, isFalse);
    expect(c.currentNode, node);
  });

  test(
    'AppController logout clears session data back to safe defaults',
    () async {
      final c = AppController();
      const node = NodeModel(
        id: 'node-1',
        name: '香港 01',
        flag: '🇭🇰',
        latency: 80,
      );

      await c.setCurrentNode(node);
      c.goToPage(AppPage.nodes);
      await c.logout();

      expect(c.isAuthenticated, isFalse);
      expect(c.page, AppPage.nodes);
      expect(c.currentNode, NodeSelectionService.emptyNode);
      expect(c.nodes, isEmpty);
      expect(c.plans, isEmpty);
      expect(c.inviteCodes, isEmpty);
      expect(c.inviteCode, isEmpty);
      expect(c.inviteLink, isEmpty);
      expect(c.withdrawable, 0);
      expect(c.traffic.totalGb, 0);
      expect(c.dailyUsage, isEmpty);
      expect(c.trafficUsage, isEmpty);
      expect(c.dataLoadError, isNull);
    },
  );
}

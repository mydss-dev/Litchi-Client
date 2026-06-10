import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/services/auto_start.dart';
import '../shared/services/settings_service.dart';

/// Owns all user-configurable settings. Persists changes via [SettingsService].
///
/// Consumed via [AppController] delegates — callers use
/// `AppScope.of(context).proxyMode` etc. unchanged.
class SettingsController extends ChangeNotifier {
  bool _autoStart = false;
  bool _autoUpdate = true;
  bool _devMode = false;
  String _language = '简体中文';
  String _proxyMode = '规则模式';
  String _dnsMode = '系统 DNS';
  int _proxyPort = 7890;
  ThemeMode _themeMode = ThemeMode.light;

  bool get autoStart => _autoStart;
  bool get autoUpdate => _autoUpdate;
  bool get devMode => _devMode;
  String get language => _language;
  String get proxyMode => _proxyMode;
  String get dnsMode => _dnsMode;
  int get proxyPort => _proxyPort;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Loads persisted settings. Called once during app init.
  /// Does not notify — caller notifies after full init completes.
  Future<void> load() async {
    final s = await SettingsService.load();
    _proxyPort = s.proxyPort;
    _autoStart = s.autoStart;
    _autoUpdate = s.autoUpdate;
    _devMode = s.devMode;
    _language = s.language;
    _proxyMode = s.proxyMode;
    _dnsMode = s.dnsMode;
    _themeMode = s.themeMode;
    // Sync registry to match the saved preference (also refreshes exe path
    // if the app was updated and moved to a new location).
    if (_autoStart) {
      unawaited(AutoStart.enable());
    } else {
      unawaited(AutoStart.disable());
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    SettingsService.setThemeMode(mode);
    notifyListeners();
  }

  void toggleDarkMode(bool enabled) =>
      setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);

  Future<void> setProxyPort(int port) async {
    if (port < 1 || port > 65535 || port == _proxyPort) return;
    _proxyPort = port;
    SettingsService.setProxyPort(port);
    notifyListeners();
  }

  void setAutoStart(bool v) {
    if (_autoStart == v) return;
    _autoStart = v;
    SettingsService.setAutoStart(v);
    if (v) {
      unawaited(AutoStart.enable());
    } else {
      unawaited(AutoStart.disable());
    }
    notifyListeners();
  }

  void setAutoUpdate(bool v) {
    if (_autoUpdate == v) return;
    _autoUpdate = v;
    SettingsService.setAutoUpdate(v);
    notifyListeners();
  }

  void setDevMode(bool v) {
    if (_devMode == v) return;
    _devMode = v;
    SettingsService.setDevMode(v);
    notifyListeners();
  }

  void setLanguage(String v) {
    if (_language == v) return;
    _language = v;
    SettingsService.setLanguage(v);
    notifyListeners();
  }

  void setProxyMode(String v) {
    if (_proxyMode == v) return;
    _proxyMode = v;
    SettingsService.setProxyMode(v);
    notifyListeners();
  }

  void setDnsMode(String v) {
    if (_dnsMode == v) return;
    _dnsMode = v;
    SettingsService.setDnsMode(v);
    notifyListeners();
  }
}

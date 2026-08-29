import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_locale_preference.dart';
import '../shared/models/app_models.dart';
import '../shared/services/auto_start.dart';
import '../shared/services/settings_service.dart';
import 'core_platform_support.dart';

/// Owns all user-configurable settings. Persists changes via [SettingsService].
///
/// Consumed via [AppController] delegates — callers use
/// `AppScope.of(context).proxyMode` etc. unchanged.
class SettingsController extends ChangeNotifier {
  bool _wasConnected = false;
  String _lastNodeId = '';
  bool _autoStart = false;
  bool _silentStart = false;
  bool _autoUpdate = true;
  AppLocalePreference _language = AppLocalePreference.system;
  ProxyMode _proxyMode = ProxyMode.rule;
  NetworkMode _networkMode = NetworkMode.system;
  DnsMode _dnsMode = DnsMode.system;
  int _proxyPort = 7890;
  bool _killSwitch = false;
  ThemeMode _themeMode = ThemeMode.light;

  bool get wasConnected => _wasConnected;
  String get lastNodeId => _lastNodeId;
  bool get autoStart => _autoStart;
  bool get silentStart => _silentStart;
  bool get autoUpdate => _autoUpdate;
  AppLocalePreference get language => _language;
  ProxyMode get proxyMode => _proxyMode;
  NetworkMode get networkMode => _networkMode;
  DnsMode get dnsMode => _dnsMode;
  int get proxyPort => _proxyPort;
  bool get killSwitch => _killSwitch;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Loads persisted settings. Called once during app init.
  /// Does not notify — caller notifies after full init completes.
  Future<void> load() async {
    final s = await SettingsService.load();
    _proxyPort = s.proxyPort;
    _autoStart = s.autoStart;
    _silentStart = s.silentStart;
    _autoUpdate = s.autoUpdate;
    _language = s.language;
    _proxyMode = s.proxyMode;
    _networkMode = CorePlatformSupport.normalizeNetworkMode(s.networkMode);
    if (_networkMode != s.networkMode) {
      SettingsService.setNetworkMode(_networkMode);
    }
    _dnsMode = s.dnsMode;
    _wasConnected = s.wasConnected;
    _lastNodeId = s.lastNodeId;
    _killSwitch = s.killSwitch;
    _themeMode = s.themeMode;
    // Sync registry to match the saved preference (also refreshes exe path
    // if the app was updated and moved to a new location).
    if (_autoStart) {
      unawaited(AutoStart.enable(silent: _silentStart));
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

  void setWasConnected(bool v) {
    if (_wasConnected == v) return;
    _wasConnected = v;
    SettingsService.setWasConnected(v);
  }

  void setLastNodeId(String id) {
    if (_lastNodeId == id) return;
    _lastNodeId = id;
    SettingsService.setLastNodeId(id);
  }

  void setAutoStart(bool v) {
    if (_autoStart == v) return;
    _autoStart = v;
    SettingsService.setAutoStart(v);
    if (v) {
      unawaited(AutoStart.enable(silent: _silentStart));
    } else {
      unawaited(AutoStart.disable());
    }
    notifyListeners();
  }

  void setSilentStart(bool v) {
    if (_silentStart == v) return;
    _silentStart = v;
    SettingsService.setSilentStart(v);
    if (_autoStart) {
      unawaited(AutoStart.enable(silent: v));
    }
    notifyListeners();
  }

  void setAutoUpdate(bool v) {
    if (_autoUpdate == v) return;
    _autoUpdate = v;
    SettingsService.setAutoUpdate(v);
    notifyListeners();
  }

  void setLanguage(AppLocalePreference v) {
    if (_language == v) return;
    _language = v;
    SettingsService.setLanguage(v);
    notifyListeners();
  }

  void setProxyMode(ProxyMode v) {
    if (_proxyMode == v) return;
    _proxyMode = v;
    SettingsService.setProxyMode(v);
    notifyListeners();
  }

  void setNetworkMode(NetworkMode v) {
    if (!CorePlatformSupport.supportsNetworkMode(v)) return;
    if (_networkMode == v) return;
    _networkMode = v;
    SettingsService.setNetworkMode(v);
    notifyListeners();
  }

  void setDnsMode(DnsMode v) {
    if (_dnsMode == v) return;
    _dnsMode = v;
    SettingsService.setDnsMode(v);
    notifyListeners();
  }

  void setKillSwitch(bool v) {
    if (_killSwitch == v) return;
    _killSwitch = v;
    SettingsService.setKillSwitch(v);
    notifyListeners();
  }
}

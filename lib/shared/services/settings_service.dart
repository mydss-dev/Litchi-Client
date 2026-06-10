import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.proxyPort,
    required this.autoStart,
    required this.autoUpdate,
    required this.devMode,
    required this.language,
    required this.proxyMode,
    required this.dnsMode,
    required this.themeMode,
  });

  final int proxyPort;
  final bool autoStart;
  final bool autoUpdate;
  final bool devMode;
  final String language;
  final String proxyMode;
  final String dnsMode;
  final ThemeMode themeMode;
}

/// Handles loading and persisting user preferences via SharedPreferences.
abstract final class SettingsService {
  static Future<SettingsSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    return SettingsSnapshot(
      proxyPort: p.getInt('proxy_port') ?? 7890,
      autoStart: p.getBool('auto_start') ?? false,
      autoUpdate: p.getBool('auto_update') ?? true,
      devMode: p.getBool('dev_mode') ?? false,
      language: p.getString('language') ?? '简体中文',
      proxyMode: _normalizeProxyMode(p.getString('proxy_mode')),
      dnsMode: p.getString('dns_mode') ?? '系统 DNS',
      themeMode: switch (p.getString('theme_mode') ?? 'light') {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
    );
  }

  static void setProxyPort(int v) =>
      SharedPreferences.getInstance().then((p) => p.setInt('proxy_port', v));

  static void setAutoStart(bool v) =>
      SharedPreferences.getInstance().then((p) => p.setBool('auto_start', v));

  static void setAutoUpdate(bool v) =>
      SharedPreferences.getInstance().then((p) => p.setBool('auto_update', v));

  static void setDevMode(bool v) =>
      SharedPreferences.getInstance().then((p) => p.setBool('dev_mode', v));

  static void setLanguage(String v) =>
      SharedPreferences.getInstance().then((p) => p.setString('language', v));

  static void setProxyMode(String v) =>
      SharedPreferences.getInstance().then((p) => p.setString('proxy_mode', v));

  static void setDnsMode(String v) =>
      SharedPreferences.getInstance().then((p) => p.setString('dns_mode', v));

  static void setThemeMode(ThemeMode m) => SharedPreferences.getInstance().then(
    (p) => p.setString('theme_mode', switch (m) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    }),
  );

  static String _normalizeProxyMode(String? v) {
    return switch (v) {
      '智能模式' => '规则模式',
      '全局模式' => '全局模式',
      '直连模式' => '直连模式',
      _ => '规则模式',
    };
  }
}

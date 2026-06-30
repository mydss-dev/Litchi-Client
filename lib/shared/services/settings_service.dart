import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import '../../l10n/app_locale_preference.dart';
import '../models/app_models.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.proxyPort,
    required this.autoStart,
    required this.autoUpdate,
    required this.language,
    required this.proxyMode,
    required this.networkMode,
    required this.dnsMode,
    required this.themeMode,
    required this.wasConnected,
    required this.lastNodeId,
    required this.killSwitch,
  });

  final int proxyPort;
  final bool autoStart;
  final bool autoUpdate;
  final AppLocalePreference language;
  final ProxyMode proxyMode;
  final NetworkMode networkMode;
  final String dnsMode;
  final ThemeMode themeMode;
  final bool wasConnected;

  /// When true, an unexpected core drop blackholes the system proxy instead of
  /// reverting to a direct (unprotected) connection — fail-closed.
  final bool killSwitch;

  /// ID of the node the user last manually selected.
  /// Empty string means "use auto-select".
  final String lastNodeId;
}

/// Handles loading and persisting user preferences via SharedPreferences.
abstract final class SettingsService {
  static String _key(String value) => AppIdentity.preferenceKey(value);

  static Future<SettingsSnapshot> load() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key('allow_insecure_nodes'));
    await p.remove(_key('close_connections_on_switch'));
    await p.remove(_key('dev_mode'));
    return SettingsSnapshot(
      proxyPort: p.getInt(_key('proxy_port')) ?? 7890,
      autoStart: p.getBool(_key('auto_start')) ?? false,
      autoUpdate: p.getBool(_key('auto_update')) ?? true,
      language: AppLocalePreference.fromStorage(p.getString(_key('language'))),
      proxyMode: ProxyMode.fromStorageKey(p.getString(_key('proxy_mode'))),
      networkMode: NetworkMode.fromStorageKey(
        p.getString(_key('network_mode')),
      ),
      dnsMode: p.getString(_key('dns_mode')) ?? '系统 DNS',
      themeMode: switch (p.getString(_key('theme_mode')) ?? 'light') {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      wasConnected: p.getBool(_key('was_connected')) ?? false,
      lastNodeId: p.getString(_key('last_node_id')) ?? '',
      killSwitch: p.getBool(_key('kill_switch')) ?? false,
    );
  }

  static void setKillSwitch(bool v) => SharedPreferences.getInstance().then(
    (p) => p.setBool(_key('kill_switch'), v),
  );

  static void setProxyPort(int v) => SharedPreferences.getInstance().then(
    (p) => p.setInt(_key('proxy_port'), v),
  );

  static void setAutoStart(bool v) => SharedPreferences.getInstance().then(
    (p) => p.setBool(_key('auto_start'), v),
  );

  static void setAutoUpdate(bool v) => SharedPreferences.getInstance().then(
    (p) => p.setBool(_key('auto_update'), v),
  );

  static void setLanguage(AppLocalePreference value) =>
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString(_key('language'), value.storageKey),
      );

  static void setProxyMode(ProxyMode v) => SharedPreferences.getInstance().then(
    (p) => p.setString(_key('proxy_mode'), v.storageKey),
  );

  static void setNetworkMode(NetworkMode v) => SharedPreferences.getInstance()
      .then((p) => p.setString(_key('network_mode'), v.storageKey));

  static void setDnsMode(String v) => SharedPreferences.getInstance().then(
    (p) => p.setString(_key('dns_mode'), v),
  );

  static void setThemeMode(ThemeMode m) => SharedPreferences.getInstance().then(
    (p) => p.setString(_key('theme_mode'), switch (m) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    }),
  );

  static void setWasConnected(bool v) => SharedPreferences.getInstance().then(
    (p) => p.setBool(_key('was_connected'), v),
  );

  static void setLastNodeId(String id) => SharedPreferences.getInstance().then(
    (p) => p.setString(_key('last_node_id'), id),
  );

  static Future<String?> loadNodeSortKey() async =>
      (await SharedPreferences.getInstance()).getString(_key('node_sort'));

  static void setNodeSortKey(String value) => SharedPreferences.getInstance()
      .then((prefs) => prefs.setString(_key('node_sort'), value));

  static Future<int> loadLastSeenNoticeId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_key('last_seen_notice_id')) ?? 0;
  }

  static void setLastSeenNoticeId(int id) => SharedPreferences.getInstance()
      .then((p) => p.setInt(_key('last_seen_notice_id'), id));

  static Future<Set<String>> loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_key('node_favorites')) ?? []).toSet();
  }

  static void saveFavorites(Set<String> ids) => SharedPreferences.getInstance()
      .then((p) => p.setStringList(_key('node_favorites'), ids.toList()));
}

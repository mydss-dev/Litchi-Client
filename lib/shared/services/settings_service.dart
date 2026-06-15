import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class SettingsSnapshot {
  const SettingsSnapshot({
    required this.proxyPort,
    required this.autoStart,
    required this.autoUpdate,
    required this.devMode,
    required this.language,
    required this.proxyMode,
    required this.networkMode,
    required this.dnsMode,
    required this.themeMode,
    required this.wasConnected,
    required this.lastNodeId,
    required this.killSwitch,
    required this.allowInsecureNodes,
  });

  final int proxyPort;
  final bool autoStart;
  final bool autoUpdate;
  final bool devMode;
  final String language;
  final ProxyMode proxyMode;
  final NetworkMode networkMode;
  final String dnsMode;
  final ThemeMode themeMode;
  final bool wasConnected;

  /// When true, an unexpected core drop blackholes the system proxy instead of
  /// reverting to a direct (unprotected) connection — fail-closed.
  final bool killSwitch;

  /// When false, nodes that request `insecure` / skip-cert-verify have that flag
  /// stripped, forcing TLS certificate validation (rejects MITM-prone nodes).
  final bool allowInsecureNodes;

  /// ID of the node the user last manually selected.
  /// Empty string means "use auto-select".
  final String lastNodeId;
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
      proxyMode: ProxyMode.fromStorageKey(p.getString('proxy_mode')),
      networkMode: NetworkMode.fromStorageKey(p.getString('network_mode')),
      dnsMode: p.getString('dns_mode') ?? '系统 DNS',
      themeMode: switch (p.getString('theme_mode') ?? 'light') {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      },
      wasConnected: p.getBool('was_connected') ?? false,
      lastNodeId: p.getString('last_node_id') ?? '',
      killSwitch: p.getBool('kill_switch') ?? false,
      allowInsecureNodes: p.getBool('allow_insecure_nodes') ?? true,
    );
  }

  static void setKillSwitch(bool v) =>
      SharedPreferences.getInstance().then((p) => p.setBool('kill_switch', v));

  static void setAllowInsecureNodes(bool v) =>
      SharedPreferences.getInstance()
          .then((p) => p.setBool('allow_insecure_nodes', v));

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

  static void setProxyMode(ProxyMode v) =>
      SharedPreferences.getInstance()
          .then((p) => p.setString('proxy_mode', v.storageKey));

  static void setNetworkMode(NetworkMode v) =>
      SharedPreferences.getInstance()
          .then((p) => p.setString('network_mode', v.storageKey));

  static void setDnsMode(String v) =>
      SharedPreferences.getInstance().then((p) => p.setString('dns_mode', v));

  static void setThemeMode(ThemeMode m) => SharedPreferences.getInstance().then(
    (p) => p.setString('theme_mode', switch (m) {
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
      _ => 'light',
    }),
  );

  static void setWasConnected(bool v) =>
      SharedPreferences.getInstance().then((p) => p.setBool('was_connected', v));

  static void setLastNodeId(String id) =>
      SharedPreferences.getInstance().then((p) => p.setString('last_node_id', id));

  static Future<int> loadLastSeenNoticeId() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('last_seen_notice_id') ?? 0;
  }

  static void setLastSeenNoticeId(int id) =>
      SharedPreferences.getInstance()
          .then((p) => p.setInt('last_seen_notice_id', id));

  static Future<Set<String>> loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList('node_favorites') ?? []).toSet();
  }

  static void saveFavorites(Set<String> ids) =>
      SharedPreferences.getInstance()
          .then((p) => p.setStringList('node_favorites', ids.toList()));

}

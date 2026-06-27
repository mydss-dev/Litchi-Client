import 'dart:io' show Platform;

import 'package:flutter/material.dart';

/// All configurable values — compile-time defaults from dart-define that can be
/// overridden at runtime by the Ed25519-signed OSS remote config.
///
/// Build a white-label version:
///   flutter build windows --release
///     --dart-define=APP_NAME="MyVPN"
///     --dart-define=LOGO_URL="https://oss.example.com/logo.png"
///     --dart-define=API_BASE="https://your-panel.com"

abstract final class AppConfig {
  // ── Version ─────────────────────────────────────────────────────────────────

  static String currentVersion = const String.fromEnvironment('APP_VERSION');

  static String updateVersion = '';
  static final Map<String, String> _updateDownloadUrls = {};
  static String updateChangelog = '';

  /// Picks the platform-specific download URL, falling back to the first
  /// available entry or the old-style flat key.
  static String get updateDownloadUrl {
    final key = _platformKey;
    if (key != null && _updateDownloadUrls.containsKey(key)) {
      return _updateDownloadUrls[key]!;
    }
    return _updateDownloadUrls.isNotEmpty
        ? _updateDownloadUrls.values.first
        : '';
  }

  static String? get _platformKey => () {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) return 'android';
    return null;
  }();

  static void setVersion(String version) {
    final v = version.trim();
    if (v.isNotEmpty) currentVersion = v;
  }

  static const double bytesPerGb = 1073741824.0;

  // ── API ─────────────────────────────────────────────────────────────────────

  static String apiBase = const String.fromEnvironment('API_BASE');

  static List<String> apiBaseList = const [];
  static List<String> get effectiveApiBases =>
      apiBaseList.isNotEmpty ? apiBaseList : [apiBase];

  static String apiPrefix = '';

  // ── Brand ──────────────────────────────────────────────────────────────────

  static String appName = const String.fromEnvironment('APP_NAME');
  static String logoUrl = const String.fromEnvironment('LOGO_URL');
  static String avatarUrl = '';

  // Keep a usable blue→purple fallback even when OSS is unavailable or an
  // older config does not contain brand colors.
  static Color brandStart = const Color(0xFF2563EB);
  static Color brandEnd = const Color(0xFF7C3AED);

  // ── URLs ────────────────────────────────────────────────────────────────────

  static String inviteUrlBase = '';
  // ── Derived ─────────────────────────────────────────────────────────────────

  static bool get isSecureServer => apiBase.startsWith('https://');
  static LinearGradient get brandGradient =>
      LinearGradient(colors: [brandStart, brandEnd]);

  static void applyRemote(Map<String, dynamic> json) {
    _str(json, 'api_prefix', (v) => apiPrefix = v);

    final bases = json['api_base_list'];
    if (bases is List) {
      final urls = bases
          .whereType<String>()
          .map((e) => e.trim().replaceAll(RegExp(r'/+$'), ''))
          .where((e) => e.startsWith('https://'))
          .toList();
      if (urls.isNotEmpty) {
        apiBase = urls.first;
        apiBaseList = urls;
      }
    }

    _str(json, 'app_name', (v) => appName = v);
    _str(json, 'logo_url', (v) => logoUrl = v);
    _url(json, 'avatar_url', (v) => avatarUrl = v);
    _firstUrl(json, [
      'invite_url_base',
      'invite_base_url',
      'invite_url',
      'frontend_url',
      'site_url',
    ], (v) => inviteUrlBase = v);

    _str(json, 'update_version', (v) => updateVersion = v);
    _updateDownloadUrlsFromJson(json['update_download_url']);
    _str(json, 'update_changelog', (v) => updateChangelog = v);
  }

  static void _updateDownloadUrlsFromJson(Object? value) {
    if (value is Map) {
      final next = <String, String>{};

      for (final entry in value.entries) {
        final platform = entry.key.toString();
        final raw = entry.value?.toString() ?? '';
        final safe = _trustedHttpsUrl(raw);
        if (safe != null) {
          next[platform] = safe;
        }
      }

      if (next.isNotEmpty) {
        _updateDownloadUrls
          ..clear()
          ..addAll(next);
      }
    }
  }

  static void _str(
    Map<String, dynamic> json,
    String key,
    void Function(String) apply,
  ) {
    final v = json[key];
    if (v is String && v.isNotEmpty) apply(v);
  }

  static void _firstUrl(
    Map<String, dynamic> json,
    List<String> keys,
    void Function(String) apply,
  ) {
    for (final key in keys) {
      final v = json[key];
      if (v is! String || v.isEmpty) continue;
      final normalized = _trustedHttpsUrl(v);
      if (normalized != null) {
        apply(normalized);
        return;
      }
    }
  }

  static void _url(
    Map<String, dynamic> json,
    String key,
    void Function(String) apply,
  ) {
    final v = json[key];
    if (v is! String || v.isEmpty) return;
    final normalized = _trustedHttpsUrl(v);
    if (normalized != null) apply(normalized);
  }

  static String? _trustedHttpsUrl(String value) {
    final trimmed = value.trim();
    final u = Uri.tryParse(trimmed);
    if (u != null && u.scheme == 'https' && u.host.isNotEmpty) return trimmed;
    return null;
  }
}

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
///     --dart-define=REMOTE_CONFIG_URL="https://oss.example.com/config.json"
///     --dart-define=REMOTE_CONFIG_PUBLIC_KEY="tenant-ed25519-public-key"

abstract final class AppConfig {
  /// Increments after a trusted remote config changes effective runtime values.
  ///
  /// Long-lived services can listen to this instead of waiting for the next
  /// process launch to pick up a refreshed OSS config.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // ── Version ─────────────────────────────────────────────────────────────────

  static String currentVersion = const String.fromEnvironment('APP_VERSION');

  static bool updatesEnabled = true;
  static String updateVersion = '';
  static final Map<String, String> _updateDownloadUrls = {};
  static final Map<String, String> _updateSha256s = {};
  static String updateChangelog = '';

  static String? get _selectedUpdateKey {
    final platform = _platformKey;
    if (platform != null && _updateDownloadUrls.containsKey(platform)) {
      return platform;
    }
    if (_updateDownloadUrls.containsKey('default')) return 'default';
    return _updateDownloadUrls.keys.firstOrNull;
  }

  /// Picks the platform-specific download URL.
  static String get updateDownloadUrl {
    final key = _selectedUpdateKey;
    return key == null ? '' : _updateDownloadUrls[key]!;
  }

  /// Picks the digest paired with the selected platform URL. A flat digest is
  /// stored under `default` and applies to every platform.
  static String get updateSha256 {
    final key = _selectedUpdateKey;
    if (key != null && _updateSha256s.containsKey(key)) {
      return _updateSha256s[key]!;
    }
    return _updateSha256s['default'] ?? '';
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
    final before = _runtimeFingerprint();

    _str(json, 'api_prefix', (v) => apiPrefix = v);

    final bases = json['api_base_list'];
    if (bases is List) {
      final urls = bases
          .whereType<String>()
          .map(_trustedHttpsUrl)
          .whereType<String>()
          .map((e) => e.replaceAll(RegExp(r'/+$'), ''))
          .toSet()
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

    final updateEnabled = json['update_enabled'];
    updatesEnabled = updateEnabled is bool ? updateEnabled : true;
    _str(json, 'update_version', (v) => updateVersion = v);
    _updateDownloadUrlsFromJson(json['update_download_url']);
    _str(json, 'update_changelog', (v) => updateChangelog = v);
    _updateSha256sFromJson(json['update_sha256']);

    if (_runtimeFingerprint() != before) {
      revision.value++;
    }
  }

  static String _runtimeFingerprint() => <Object?>[
    apiBase,
    ...apiBaseList,
    apiPrefix,
    appName,
    logoUrl,
    avatarUrl,
    inviteUrlBase,
    updatesEnabled,
    updateVersion,
    for (final entry
        in (_updateDownloadUrls.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
      '${entry.key}=${entry.value}',
    updateChangelog,
    for (final entry
        in (_updateSha256s.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
      '${entry.key}=${entry.value}',
  ].join('\u0000');

  static void _updateDownloadUrlsFromJson(Object? value) {
    if (value is String) {
      final safe = _trustedHttpsUrl(value);
      if (safe != null) {
        _updateDownloadUrls
          ..clear()
          ..['default'] = safe;
      }
      return;
    }
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

  static void _updateSha256sFromJson(Object? value) {
    if (value is String) {
      _updateSha256s
        ..clear()
        ..['default'] = value.trim().toLowerCase();
      return;
    }
    if (value is Map) {
      final next = <String, String>{};
      for (final entry in value.entries) {
        if (entry.value is! String) continue;
        next[entry.key.toString()] = (entry.value as String)
            .trim()
            .toLowerCase();
      }
      if (next.isNotEmpty) {
        _updateSha256s
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

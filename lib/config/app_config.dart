import 'package:flutter/material.dart';

import 'panel_backend.dart';

/// Runtime values populated from the Ed25519-signed OSS configuration.

abstract final class AppConfig {
  /// Increments after a trusted remote config changes effective runtime values.
  ///
  /// Long-lived services can listen to this instead of waiting for the next
  /// process launch to pick up a refreshed OSS config.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  // ── Version ─────────────────────────────────────────────────────────────────

  static String currentVersion = const String.fromEnvironment('APP_VERSION');

  /// Global kill switch: a trusted remote config may disable update checks
  /// entirely (e.g. while a broken release is pulled). Update metadata itself
  /// never lives here — it comes exclusively from the signed update.json.
  static bool updatesEnabled = true;

  static void setVersion(String version) {
    final v = version.trim();
    if (v.isNotEmpty) currentVersion = v;
  }

  static const double bytesPerGb = 1073741824.0;

  // ── API ─────────────────────────────────────────────────────────────────────

  /// Primary panel API selected from the signed remote config.
  static String apiBase = '';

  /// Trusted panel API endpoints from `config.json`.
  static List<String> apiBaseList = const [];
  static List<String> get effectiveApiBases => apiBaseList;

  static String apiPrefix = '';
  static PanelType panelType = PanelType.v2board;
  static PanelFeatures panelFeatures = PanelFeatures.legacy;

  // ── Brand ──────────────────────────────────────────────────────────────────

  /// Runtime branding (name + avatar) comes only from the trusted signed
  /// remote config. The brand logo is baked in at build time, so it is not
  /// parsed here. These defaults are used only before a trusted config is
  /// available.
  static String appName = 'Litchi';
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
    final configuredPanelType = PanelType.tryParse(json['panel_type']);
    if (configuredPanelType != null) {
      panelType = configuredPanelType;
      panelFeatures = PanelFeatures.defaultsFor(panelType);
    }
    panelFeatures = panelFeatures.apply(json['panel_features']);

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

    if (_runtimeFingerprint() != before) {
      revision.value++;
    }
  }

  static String _runtimeFingerprint() => <Object?>[
    apiBase,
    ...apiBaseList,
    apiPrefix,
    panelType.configValue,
    panelFeatures.fingerprint,
    appName,
    avatarUrl,
    inviteUrlBase,
    updatesEnabled,
  ].join('\u0000');

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

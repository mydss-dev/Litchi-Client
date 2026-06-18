import 'package:flutter/widgets.dart';

import '../../config/brand.dart';

/// Runtime app configuration.
///
/// Fields start with compiled dart-define defaults and are overridden by
/// [RemoteConfigService] on startup (before runApp). All UI and service code
/// should read from here — never directly from [BrandConfig] or dart-define.
abstract final class AppConfig {
  // ── Compile-time only (never remote-overridden) ───────────────────────────

  /// Semantic version of this build. Single source of truth: populated at
  /// startup from the platform package metadata (pubspec `version`) via
  /// [initVersion]. The dart-define value is only the pre-init fallback.
  static String currentVersion = const String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.2.0',
  );

  /// Overwrites [currentVersion] with the real installed version. Call once in
  /// main() before the update check runs.
  static void setVersion(String version) {
    final v = version.trim();
    if (v.isNotEmpty) currentVersion = v;
  }

  static const double bytesPerGb = 1073741824.0;

  // ── Remote-overridable fields ─────────────────────────────────────────────
  // Initial values come from dart-define; RemoteConfigService overwrites these
  // before runApp() so the first frame already has the correct values.

  static String apiBase = const String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api-xiao.top',
  );

  /// Optional failover list of API base URLs (remote key 'api_base_list'). The
  /// client tries them in order and sticks to the first that responds, so a
  /// blocked domain auto-falls back to the next without user action. Empty ⇒
  /// just [apiBase].
  static List<String> apiBaseList = const [];

  /// The effective ordered list of API bases to try.
  static List<String> get effectiveApiBases =>
      apiBaseList.isNotEmpty ? apiBaseList : [apiBase];

  static String updateCheckUrl = const String.fromEnvironment(
    'UPDATE_CHECK_URL',
    defaultValue: '',
  );

  /// Update info carried directly in the (signed) remote config — no separate
  /// manifest fetch. When [latestVersion] is newer than [currentVersion] the
  /// client shows the update banner; [downloadUrl] is also used by the
  /// force-update dialog. Empty [latestVersion] ⇒ fall back to [updateCheckUrl].
  static String latestVersion = '';
  static String downloadUrl = '';
  static String changelog = '';

  /// User-Agent sent on panel API requests. Defaults to a current desktop
  /// Chrome string so the control-plane traffic blends in with normal web
  /// browsing instead of exposing a Dart/dart:io client. Override via remote
  /// config ('api_user_agent') to rotate the fingerprint without a rebuild.
  static String apiUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

  /// Path prefix for the panel API. Defaults to the V2board-standard '/api/v1'.
  /// Set this (remote key 'api_path_prefix') to a secret prefix that a reverse
  /// proxy maps back to '/api/v1' — so active probes of '/api/v1/...' find
  /// nothing and the panel's path signature is hidden. Sub-paths
  /// ('/passport/...', '/user/...') are unchanged; only the prefix moves.
  static String apiPathPrefix = const String.fromEnvironment(
    'API_PATH_PREFIX',
    defaultValue: '/api/v1',
  );

  static String appName = BrandConfig.appName;
  static String appSubtitle = BrandConfig.appSubtitle;
  static String logoLetter = BrandConfig.logoLetter;
  static Color brandStart = BrandConfig.brandStart;
  static Color brandEnd = BrandConfig.brandEnd;

  /// Invite URL fallback base from remote config.
  /// Used only when the panel does not return a ready invite URL:
  ///   {inviteUrlBase}/register?code={inviteCode}
  /// Empty string = wait for remote config/backend config.
  static String inviteUrlBase = const String.fromEnvironment(
    'FRONTEND_URL',
    defaultValue: '',
  );

  /// Customer support / community link (Telegram, WeChat, etc.).
  /// Empty string = hide support entry in settings.
  static String supportUrl = '';

  /// Minimum required client version (e.g. "1.2.0").
  /// Empty string = no enforcement.
  static String minVersion = '';

  // ── Derived ───────────────────────────────────────────────────────────────

  static bool get isSecureServer => apiBase.startsWith('https://');

  static LinearGradient get brandGradient =>
      LinearGradient(colors: [brandStart, brandEnd]);

  /// True when the running build is below [minVersion].
  static bool get isVersionOutdated {
    if (minVersion.isEmpty) return false;
    return _versionBelow(currentVersion, minVersion);
  }

  static bool _versionBelow(String current, String min) {
    int seg(String v, int i) {
      final parts = v.split('.');
      return i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    }

    for (var i = 0; i < 3; i++) {
      final c = seg(current, i), m = seg(min, i);
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  // ── Remote override ───────────────────────────────────────────────────────

  static void applyRemote(Map<String, dynamic> json) {
    _url(json, 'api_base', (v) => apiBase = v);
    _url(json, 'update_check_url', (v) => updateCheckUrl = v);
    _str(json, 'api_user_agent', (v) => apiUserAgent = v);
    _str(json, 'api_path_prefix', (v) => apiPathPrefix = v);
    _str(json, 'latest_version', (v) => latestVersion = v);
    _str(json, 'download_url', (v) => downloadUrl = v);
    _str(json, 'changelog', (v) => changelog = v);
    final bases = json['api_base_list'];
    if (bases is List) {
      final urls = bases
          .whereType<String>()
          .map((e) => e.trim().replaceAll(RegExp(r'/+$'), ''))
          .where((e) => e.startsWith('https://'))
          .toList();
      if (urls.isNotEmpty) apiBaseList = urls;
    }
    _str(json, 'app_name', (v) => appName = v);
    _str(json, 'app_subtitle', (v) => appSubtitle = v);
    _str(json, 'logo_letter', (v) => logoLetter = v);
    _firstStr(json, [
      'invite_url_base',
      'invite_base_url',
      'invite_url',
      'frontend_url',
      'site_url',
    ], (v) => inviteUrlBase = v);
    _str(json, 'support_url', (v) => supportUrl = v);
    _str(json, 'min_version', (v) => minVersion = v);
    _color(json, 'brand_color_start', (v) => brandStart = v);
    _color(json, 'brand_color_end', (v) => brandEnd = v);
  }

  static void _str(
    Map<String, dynamic> json,
    String key,
    void Function(String) apply,
  ) {
    final v = json[key];
    if (v is String && v.isNotEmpty) apply(v);
  }

  static void _firstStr(
    Map<String, dynamic> json,
    List<String> keys,
    void Function(String) apply,
  ) {
    for (final key in keys) {
      final v = json[key];
      if (v is String && v.isNotEmpty) {
        apply(v);
        return;
      }
    }
  }

  /// Like [_str], but only accepts well-formed http(s) URLs — protects the
  /// app from a corrupted/malicious remote config redirecting all requests.
  static void _url(
    Map<String, dynamic> json,
    String key,
    void Function(String) apply,
  ) {
    final v = json[key];
    if (v is! String || v.isEmpty) return;
    final u = Uri.tryParse(v);
    if (u != null && u.scheme == 'https' && u.host.isNotEmpty) {
      apply(v);
    }
  }

  static void _color(
    Map<String, dynamic> json,
    String key,
    void Function(Color) apply,
  ) {
    final v = json[key];
    if (v is String && v.isNotEmpty) {
      try {
        apply(Color(int.parse('FF${v.replaceAll('#', '')}', radix: 16)));
      } catch (_) {}
    }
  }
}

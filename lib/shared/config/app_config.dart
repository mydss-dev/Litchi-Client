import 'package:flutter/widgets.dart';

import '../../config/brand.dart';

/// Runtime app configuration.
///
/// Fields start with compiled dart-define defaults and are overridden by
/// [RemoteConfigService] on startup (before runApp). All UI and service code
/// should read from here — never directly from [BrandConfig] or dart-define.
abstract final class AppConfig {
  // ── Compile-time only (never remote-overridden) ───────────────────────────

  /// Semantic version of this build.
  static const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.1.0',
  );

  static const double bytesPerGb = 1073741824.0;

  // ── Remote-overridable fields ─────────────────────────────────────────────
  // Initial values come from dart-define; RemoteConfigService overwrites these
  // before runApp() so the first frame already has the correct values.

  static String apiBase = const String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api-xiao.top',
  );

  static String updateCheckUrl = const String.fromEnvironment(
    'UPDATE_CHECK_URL',
    defaultValue: '',
  );

  static String appName          = BrandConfig.appName;
  static String appSubtitle      = BrandConfig.appSubtitle;
  static String logoLetter       = BrandConfig.logoLetter;
  static Color  brandStart       = BrandConfig.brandStart;
  static Color  brandEnd         = BrandConfig.brandEnd;

  /// Invite URL domain override.
  /// When set, the invite link is rebuilt as:
  ///   {inviteUrlBase}/register?code={inviteCode}
  /// This lets you change the panel domain without touching the backend.
  /// Empty string = use the URL returned by the API as-is.
  static String inviteUrlBase    = '';

  /// Customer support / community link (Telegram, WeChat, etc.).
  /// Empty string = hide support entry in settings.
  static String supportUrl       = '';

  /// Minimum required client version (e.g. "1.2.0").
  /// Empty string = no enforcement.
  static String minVersion       = '';

  /// Whether new user registration is open.
  static bool   registerEnabled  = true;

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
    _url(json, 'api_base',           (v) => apiBase          = v);
    _url(json, 'update_check_url',   (v) => updateCheckUrl  = v);
    _str(json, 'app_name',           (v) => appName         = v);
    _str(json, 'app_subtitle',       (v) => appSubtitle     = v);
    _str(json, 'logo_letter',        (v) => logoLetter      = v);
    _str(json, 'invite_url_base',    (v) => inviteUrlBase   = v);
    _str(json, 'support_url',        (v) => supportUrl      = v);
    _str(json, 'min_version',        (v) => minVersion      = v);
    _color(json, 'brand_color_start',(v) => brandStart      = v);
    _color(json, 'brand_color_end',  (v) => brandEnd        = v);
    final reg = json['register_enabled'];
    if (reg is bool) registerEnabled = reg;
  }

  static void _str(
    Map<String, dynamic> json,
    String key,
    void Function(String) apply,
  ) {
    final v = json[key];
    if (v is String && v.isNotEmpty) apply(v);
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
    if (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty) {
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

abstract final class AppConfig {
  /// Panel API base URL — no trailing slash.
  /// Override at build time: --dart-define=API_BASE=https://your-host.com
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://api-xiao.top',
  );

  /// Semantic version of this build (matches pubspec version name).
  /// Override at build time: --dart-define=APP_VERSION=1.2.0
  static const String currentVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.1.0',
  );

  /// URL returning a JSON version manifest for auto-update checks.
  /// Expected shape: {"version":"1.2.0","download_url":"...","changelog":"..."}
  /// Empty string (default) disables update checks entirely.
  static const String updateCheckUrl = String.fromEnvironment(
    'UPDATE_CHECK_URL',
    defaultValue: '',
  );

  /// True when the panel API base URL uses HTTPS.
  static bool get isSecureServer => apiBase.startsWith('https://');

  /// Bytes per GiB — used for all traffic calculations.
  static const double bytesPerGb = 1073741824.0;
}

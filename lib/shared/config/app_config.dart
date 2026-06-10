abstract final class AppConfig {
  /// Panel API base URL — no trailing slash.
  static const String apiBase = String.fromEnvironment(
    'LITCHI_API_BASE',
    defaultValue: 'https://api-xiao.top',
  );

  /// Bytes per GiB — used for all traffic calculations.
  static const double bytesPerGb = 1073741824.0;
}

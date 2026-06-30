abstract final class AppIdentity {
  static const String buildId = String.fromEnvironment(
    'APP_ID',
    defaultValue: 'litchi',
  );

  static String storageKeyFor(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? 'litchi' : normalized;
  }

  static String get storageKey => storageKeyFor(buildId);

  static String storageDirectoryNameFor(String value) {
    final key = storageKeyFor(value);
    return key == 'litchi' ? 'Litchi' : key;
  }

  static String get storageDirectoryName => storageDirectoryNameFor(buildId);

  /// Stable, OS-visible TUN adapter name for this build.
  ///
  /// White-label builds use APP_ID instead of the remotely changeable app
  /// name so an OSS rename cannot invalidate an active adapter or WFP rule.
  static String tunInterfaceAliasFor(String value) {
    final key = storageKeyFor(value);
    if (key == 'litchi') return 'Litchi';
    final suffix = key.length > 48 ? key.substring(0, 48) : key;
    return 'VPN-$suffix';
  }

  static String get tunInterfaceAlias => tunInterfaceAliasFor(buildId);

  static String get instancePing => 'LITCHI_FOCUS_V1:$storageKey';
  static String get instancePong => 'LITCHI_FOCUS_OK_V1:$storageKey';

  static int instanceLockPortFor(String value) {
    final key = storageKeyFor(value);
    if (key == 'litchi') return 54891;
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 49152 + (hash % (65535 - 49152));
  }

  static int get instanceLockPort => instanceLockPortFor(buildId);

  static String autoStartValueNameFor(String value) {
    final key = storageKeyFor(value);
    return key == 'litchi' ? 'LitchiClient' : key;
  }

  static String get autoStartValueName => autoStartValueNameFor(buildId);

  static String preferenceKeyFor(String identity, String key) {
    final namespace = storageKeyFor(identity);
    return namespace == 'litchi' ? key : '$namespace:$key';
  }

  static String preferenceKey(String key) => preferenceKeyFor(buildId, key);
}

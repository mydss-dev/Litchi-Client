abstract final class AppIdentity {
  static const storageKey = 'litchi';
  static const storageDirectoryName = 'Litchi';
  static const tunInterfaceAlias = 'TUN-LOCAL';
  static const instancePing = 'LITCHI_FOCUS_V1:litchi';
  static const instancePong = 'LITCHI_FOCUS_OK_V1:litchi';
  static const instanceLockPort = 54891;
  static const autoStartValueName = 'LitchiClient';

  static String preferenceKey(String key) => key;
}

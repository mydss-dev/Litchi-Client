/// Central place for OSS remote-config settings.
///
/// Most releases only need to edit this file when rotating the config URL or
/// installing the Ed25519 public key used to verify signed OSS config.
abstract final class RemoteConfigSettings {
  /// OSS URL for the remote config wrapper or legacy JSON config.
  static const configUrl = 'https://oss.qingniaojiasu.top/config.json';

  /// SharedPreferences key for the last trusted remote config body.
  static const cacheKey = 'remote_config_v1';

  /// Network timeout for fetching the OSS config.
  static const timeout = Duration(seconds: 5);

  /// Ed25519 public key, encoded with base64url without padding.
  ///
  /// Generate once with:
  ///   dart run tool/sign_remote_config.dart generate
  ///
  /// Put PUBLIC_KEY here. Keep PRIVATE_KEY offline and never commit it.
  /// While this is left as the placeholder value, unsigned legacy config is
  /// still accepted for rollout compatibility.
  static const publicKeyBase64Url = 'REPLACE_WITH_ED25519_PUBLIC_KEY';
}

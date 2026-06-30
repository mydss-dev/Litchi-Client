import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import 'secure_logger.dart';
import 'windows_dpapi.dart';

/// Stores remembered login credentials.
///
/// | Platform  | Backend                             |
/// |-----------|-------------------------------------|
/// | Android   | FlutterSecureStorage (Keystore)     |
/// | iOS       | FlutterSecureStorage (Keychain)     |
/// | macOS     | FlutterSecureStorage (Keychain)     |
/// | Windows   | DPAPI via [WindowsDpapi]            |
/// | Linux     | No secure backend — saving disabled |
///
/// macOS Keychain requires a signed app with a keychain-access-groups
/// entitlement. Ad-hoc / unsigned builds may fail with -34018
/// (errSecMissingEntitlement). Release builds must include the
/// entitlement to use Keychain.
abstract final class CredentialsStorage {
  static String get _keyEmail => AppIdentity.preferenceKey('remember_email');
  static String get _legacyKeyEmail => AppIdentity.preferenceKey('dpapi_email');
  static String get _keyPassword => AppIdentity.preferenceKey('dpapi_password');
  static const _plainPrefix = 'P:';

  static const _secureStorage = FlutterSecureStorage();

  /// Android, iOS and macOS use the OS secure store (Keystore / Keychain).
  /// Windows uses DPAPI. Linux has no secure backend and must not silently
  /// fall back to base64.
  static bool get _useSecureStorage =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    if (_useSecureStorage) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await _secureStorage.write(key: _keyPassword, value: password);
      return;
    }
    if (Platform.isLinux) {
      SecureLogger.warn('CredentialsStorage.save: no secure backend on Linux');
      return;
    }
    try {
      final encPass = await protectString(password);
      if (encPass == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await prefs.remove(_legacyKeyEmail);
      await prefs.setString(_keyPassword, encPass);
    } catch (e) {
      SecureLogger.warn('CredentialsStorage.save failed', e);
    }
  }

  static Future<({String email, String password})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_useSecureStorage) {
      final email = await _loadEmail(prefs);
      var password = await _secureStorage.read(key: _keyPassword);
      // Migration: macOS may have a legacy P:base64 blob from before Keychain
      // was enabled. Read it once, re-save to Keychain, and remove the blob.
      if ((password == null || password.isEmpty) && Platform.isMacOS) {
        final legacyEnc = prefs.getString(_keyPassword);
        if (legacyEnc != null && legacyEnc.isNotEmpty) {
          final legacyPassword = await unprotectString(legacyEnc);
          if (legacyPassword != null && legacyPassword.isNotEmpty) {
            await _secureStorage.write(
              key: _keyPassword,
              value: legacyPassword,
            );
            await prefs.remove(_keyPassword);
            password = legacyPassword;
          }
        }
      }
      if (email == null || email.isEmpty || password == null) return null;
      return (email: email, password: password);
    }
    try {
      final email = await _loadEmail(prefs);
      final encPass = prefs.getString(_keyPassword);
      if (email == null || email.isEmpty || encPass == null) return null;
      final password = await unprotectString(encPass);
      if (password == null) return null;
      return (email: email, password: password);
    } catch (e) {
      SecureLogger.warn('CredentialsStorage.load failed', e);
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_legacyKeyEmail);
    await prefs.remove(_keyPassword);
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _keyPassword);
    }
  }

  /// Clears only the remembered password while keeping the email available for
  /// autofill. Used when a legacy/corrupt password blob is detected.
  static Future<void> clearPassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPassword);
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _keyPassword);
    }
  }

  static Future<String?> _loadEmail(SharedPreferences prefs) async {
    final email = prefs.getString(_keyEmail);
    if (email != null && email.isNotEmpty) return email;

    // Migration from the old DPAPI-encrypted email key.
    final legacy = prefs.getString(_legacyKeyEmail);
    if (legacy == null || legacy.isEmpty) return null;
    final migrated = await unprotectString(legacy);
    await prefs.remove(_legacyKeyEmail);
    if (migrated == null || migrated.isEmpty) return null;
    await prefs.setString(_keyEmail, migrated);
    return migrated;
  }

  // ── Auth token (session) ──────────────────────────────────────────────────

  static const _keyAuthToken = 'dpapi_auth_token';

  static Future<void> saveAuthToken(String token) async {
    if (_useSecureStorage) {
      await _secureStorage.write(key: _keyAuthToken, value: token);
      return;
    }
    if (Platform.isLinux) {
      SecureLogger.warn(
        'CredentialsStorage.saveAuthToken: no secure backend on Linux',
      );
      return;
    }
    try {
      final enc = await protectString(token);
      if (enc == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, enc);
    } catch (e) {
      SecureLogger.warn('CredentialsStorage.saveAuthToken failed', e);
    }
  }

  static Future<String?> loadAuthToken() async {
    if (_useSecureStorage) {
      var token = await _secureStorage.read(key: _keyAuthToken);
      // Migration: macOS may have a legacy P:base64 blob.
      if ((token == null || token.isEmpty) && Platform.isMacOS) {
        final prefs = await SharedPreferences.getInstance();
        final legacyEnc = prefs.getString(_keyAuthToken);
        if (legacyEnc != null && legacyEnc.isNotEmpty) {
          final legacyToken = await unprotectString(legacyEnc);
          if (legacyToken != null && legacyToken.isNotEmpty) {
            await _secureStorage.write(key: _keyAuthToken, value: legacyToken);
            await prefs.remove(_keyAuthToken);
            token = legacyToken;
          }
        }
      }
      return token;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc = prefs.getString(_keyAuthToken);
      if (enc == null || enc.isEmpty) return null;
      return await unprotectString(enc);
    } catch (e) {
      SecureLogger.warn('CredentialsStorage.loadAuthToken failed', e);
      return null;
    }
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    if (_useSecureStorage) {
      await _secureStorage.delete(key: _keyAuthToken);
    }
  }

  // ── Generic protected strings ─────────────────────────────────────────────

  /// Sentinel prefix stored on disk as a pointer into platform secure storage.
  /// The actual payload lives in FlutterSecureStorage (Android Keystore /
  /// iOS Keychain / macOS Keychain). Only used when caller writes the returned
  /// string to a file and later passes it back to [unprotectString].
  static const _secureStorageRef = '__SECURE_STORAGE_REF__';

  /// Protects arbitrary sensitive text.
  ///
  /// | Platform  | Backend                                  |
  /// |-----------|------------------------------------------|
  /// | Windows   | DPAPI (CryptProtectData)                 |
  /// | Android   | FlutterSecureStorage (Keystore)          |
  /// | iOS       | FlutterSecureStorage (Keychain)          |
  /// | macOS     | FlutterSecureStorage (Keychain)          |
  /// | Linux     | No secure backend — returns `null`       |
  ///
  /// Android / iOS / macOS return a `__SECURE_STORAGE_REF__:<key>` sentinel
  /// that callers persist as-is; [unprotectString] resolves it back to the
  /// plaintext from the platform store. Windows returns a DPAPI blob.
  /// Callers must handle `null` (Linux) gracefully.
  static Future<String?> protectString(
    String plaintext, {
    String slot = 'secure_nodes_cache',
  }) async {
    if (Platform.isWindows) {
      return _protectDpapi(plaintext);
    }
    if (_useSecureStorage) {
      // [slot] keys the secure-storage entry so multiple callers do not
      // overwrite each other. The default preserves the original key for
      // backward compatibility with already-stored values.
      await _secureStorage.write(key: slot, value: plaintext);
      return '$_secureStorageRef:$slot';
    }
    // Linux — no secure backend.
    return null;
  }

  /// Unprotects text returned by [protectString].
  ///
  /// Resolves `__SECURE_STORAGE_REF__:<key>` sentinels from platform secure
  /// storage. Legacy `P:` (base64) payloads are still readable for migration
  /// but new writes never produce them. The removed `FB:` XOR path is
  /// rejected so callers never silently depend on it.
  static Future<String?> unprotectString(String encrypted) async {
    if (encrypted.startsWith(_secureStorageRef)) {
      final key = encrypted.substring(_secureStorageRef.length + 1);
      return _secureStorage.read(key: key);
    }
    if (encrypted.startsWith('FB:')) return null;
    if (encrypted.startsWith(_plainPrefix)) {
      try {
        return utf8.decode(
          base64.decode(encrypted.substring(_plainPrefix.length)),
        );
      } catch (_) {
        // intentional: parse attempt, fallback handled below
        return null;
      }
    }
    return _unprotectDpapi(encrypted);
  }

  // ── DPAPI via native Win32 FFI (CryptProtectData) ─────────────────────────

  static Future<String?> _protectDpapi(String plaintext) async =>
      WindowsDpapi.protect(plaintext);

  static Future<String?> _unprotectDpapi(String encrypted) async =>
      WindowsDpapi.unprotect(encrypted);
}

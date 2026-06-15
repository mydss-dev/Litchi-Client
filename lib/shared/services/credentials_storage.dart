import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_logger.dart';
import 'windows_dpapi.dart';

/// Stores remembered login credentials.
///
/// The account/email is stored as plain text for reliable autofill. The
/// password is encrypted via Windows DPAPI (native CryptProtectData over FFI —
/// no PowerShell, so the secret never appears on a process command line).
///
/// The on-disk format is a hex DPAPI blob, byte-compatible with the legacy
/// PowerShell `ConvertFrom-SecureString` output, so existing remembered logins
/// keep working across the upgrade.
abstract final class CredentialsStorage {
  static const _keyEmail = 'remember_email';
  static const _legacyKeyEmail = 'dpapi_email';
  static const _keyPassword = 'dpapi_password';
  static const _plainPrefix = 'P:';
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    if (!Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await _secureStorage.write(key: _keyPassword, value: password);
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
    if (!Platform.isWindows) {
      final prefs = await SharedPreferences.getInstance();
      final email = await _loadEmail(prefs);
      final password = await _secureStorage.read(key: _keyPassword);
      if (email == null || email.isEmpty || password == null) return null;
      return (email: email, password: password);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
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
    if (!Platform.isWindows) {
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
    if (!Platform.isWindows) {
      await _secureStorage.write(key: _keyAuthToken, value: token);
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
    if (!Platform.isWindows) {
      return _secureStorage.read(key: _keyAuthToken);
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
    if (!Platform.isWindows) {
      await _secureStorage.delete(key: _keyAuthToken);
    }
  }

  // ── Generic protected strings ─────────────────────────────────────────────

  /// Protects arbitrary sensitive text with the same DPAPI path used for
  /// credentials. Used by secure local caches that must survive app restarts.
  static Future<String?> protectString(String plaintext) => Platform.isWindows
      ? _protectDpapi(plaintext)
      : Future.value(null);

  /// Unprotects text returned by [protectString]. Legacy weak fallback payloads
  /// are rejected so callers never silently depend on the removed XOR path.
  static Future<String?> unprotectString(String encrypted) async {
    if (encrypted.startsWith('FB:')) return null;
    if (encrypted.startsWith(_plainPrefix)) {
      try {
        return utf8.decode(
          base64.decode(encrypted.substring(_plainPrefix.length)),
        );
      } catch (_) {
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

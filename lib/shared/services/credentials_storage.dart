import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores remembered login credentials.
///
/// The account/email is stored as plain text for reliable autofill. The
/// password is encrypted via Windows DPAPI.
abstract final class CredentialsStorage {
  static const _keyEmail = 'remember_email';
  static const _legacyKeyEmail = 'dpapi_email';
  static const _keyPassword = 'dpapi_password';

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    try {
      final encPass = await _protect(password);
      if (encPass == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
      await prefs.remove(_legacyKeyEmail);
      await prefs.setString(_keyPassword, encPass);
    } catch (_) {}
  }

  static Future<({String email, String password})?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = await _loadEmail(prefs);
      final encPass = prefs.getString(_keyPassword);
      if (email == null || email.isEmpty || encPass == null) return null;
      final password = await _unprotect(encPass);
      if (password == null) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_legacyKeyEmail);
    await prefs.remove(_keyPassword);
  }

  static Future<String?> _loadEmail(SharedPreferences prefs) async {
    final email = prefs.getString(_keyEmail);
    if (email != null && email.isNotEmpty) return email;

    // Migration from the old DPAPI-encrypted email key. If decryption fails,
    // do not surface the encrypted blob in the input field.
    final legacy = prefs.getString(_legacyKeyEmail);
    if (legacy == null || legacy.isEmpty) return null;
    final migrated = await _unprotect(legacy);
    await prefs.remove(_legacyKeyEmail);
    if (migrated == null || migrated.isEmpty) return null;
    await prefs.setString(_keyEmail, migrated);
    return migrated;
  }

  // ── Auth token (session) ──────────────────────────────────────────────────

  static const _keyAuthToken = 'dpapi_auth_token';

  static Future<void> saveAuthToken(String token) async {
    try {
      final enc = await _protect(token);
      if (enc == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, enc);
    } catch (_) {}
  }

  static Future<String?> loadAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enc = prefs.getString(_keyAuthToken);
      if (enc == null || enc.isEmpty) return null;
      return await _unprotect(enc);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
  }

  // ── DPAPI via PowerShell ──────────────────────────────────────────────────

  /// Encrypt [plaintext] with DPAPI. Returns base64url-safe encrypted blob.
  static Future<String?> _protect(String plaintext) async {
    // Base64-encode input to avoid PowerShell special-char issues.
    final b64in = base64.encode(utf8.encode(plaintext));
    final outPath = _tmpPath('litchi_p_out');

    final script =
        '''
\$b=[Convert]::FromBase64String('$b64in')
\$t=[Text.Encoding]::UTF8.GetString(\$b)
\$s=ConvertTo-SecureString \$t -AsPlainText -Force
ConvertFrom-SecureString \$s|Set-Content '$outPath' -Encoding ASCII -NoNewline
''';

    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]);

    final f = File(outPath);
    if (!f.existsSync()) return null;
    final result = (await f.readAsString()).trim();
    try {
      await f.delete();
    } catch (_) {}
    return result.isNotEmpty ? result : null;
  }

  /// Decrypt a blob previously created by [_protect].
  static Future<String?> _unprotect(String encrypted) async {
    final inPath = _tmpPath('litchi_u_in');
    final outPath = _tmpPath('litchi_u_out');
    await File(inPath).writeAsString(encrypted, flush: true);

    final script =
        '''
\$enc=(Get-Content '$inPath' -Raw -Encoding ASCII).Trim()
\$s=ConvertTo-SecureString \$enc
\$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR(\$s)
\$plain=[Runtime.InteropServices.Marshal]::PtrToStringAuto(\$ptr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR(\$ptr)
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(\$plain))|Set-Content '$outPath' -Encoding ASCII -NoNewline
''';

    await Process.run('powershell', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      script,
    ]);

    final inF = File(inPath);
    final outF = File(outPath);
    try {
      await inF.delete();
    } catch (_) {}

    if (!outF.existsSync()) return null;
    final b64out = (await outF.readAsString()).trim();
    try {
      await outF.delete();
    } catch (_) {}

    try {
      return utf8.decode(base64.decode(b64out));
    } catch (_) {
      return null;
    }
  }

  static String _tmpPath(String name) =>
      '${Directory.systemTemp.path}/$name.tmp';
}

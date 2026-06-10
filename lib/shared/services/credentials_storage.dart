import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores login credentials encrypted via Windows DPAPI.
///
/// Uses PowerShell's ConvertTo/From-SecureString which calls DPAPI under
/// the hood — the encrypted blob can only be decrypted by the same Windows
/// user on the same machine.
abstract final class CredentialsStorage {
  static const _keyEmail    = 'dpapi_email';
  static const _keyPassword = 'dpapi_password';

  static Future<void> save({
    required String email,
    required String password,
  }) async {
    try {
      final encEmail = await _protect(email);
      final encPass  = await _protect(password);
      if (encEmail == null || encPass == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail,    encEmail);
      await prefs.setString(_keyPassword, encPass);
    } catch (_) {}
  }

  static Future<({String email, String password})?> load() async {
    try {
      final prefs    = await SharedPreferences.getInstance();
      final encEmail = prefs.getString(_keyEmail);
      final encPass  = prefs.getString(_keyPassword);
      if (encEmail == null || encPass == null) return null;
      final email    = await _unprotect(encEmail);
      final password = await _unprotect(encPass);
      if (email == null || email.isEmpty || password == null) return null;
      return (email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPassword);
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

    final script = '''
\$b=[Convert]::FromBase64String('$b64in')
\$t=[Text.Encoding]::UTF8.GetString(\$b)
\$s=ConvertTo-SecureString \$t -AsPlainText -Force
ConvertFrom-SecureString \$s|Set-Content '$outPath' -Encoding ASCII -NoNewline
''';

    await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);

    final f = File(outPath);
    if (!f.existsSync()) return null;
    final result = (await f.readAsString()).trim();
    try { await f.delete(); } catch (_) {}
    return result.isNotEmpty ? result : null;
  }

  /// Decrypt a blob previously created by [_protect].
  static Future<String?> _unprotect(String encrypted) async {
    final inPath  = _tmpPath('litchi_u_in');
    final outPath = _tmpPath('litchi_u_out');
    await File(inPath).writeAsString(encrypted, flush: true);

    final script = '''
\$enc=(Get-Content '$inPath' -Raw -Encoding ASCII).Trim()
\$s=ConvertTo-SecureString \$enc
\$ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR(\$s)
\$plain=[Runtime.InteropServices.Marshal]::PtrToStringAuto(\$ptr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR(\$ptr)
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(\$plain))|Set-Content '$outPath' -Encoding ASCII -NoNewline
''';

    await Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', script]);

    final inF  = File(inPath);
    final outF = File(outPath);
    try { await inF.delete(); } catch (_) {}

    if (!outF.existsSync()) return null;
    final b64out = (await outF.readAsString()).trim();
    try { await outF.delete(); } catch (_) {}

    try {
      return utf8.decode(base64.decode(b64out));
    } catch (_) {
      return null;
    }
  }

  static String _tmpPath(String name) =>
      '${Directory.systemTemp.path}/$name.tmp';
}

import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import 'credentials_storage.dart';

class TokenStorage {
  // Legacy key — plain-text SharedPreferences from before DPAPI migration.
  static String get _keyAuthData => AppIdentity.preferenceKey('auth_data');

  static Future<String?> getAuthData() async {
    // Try DPAPI-encrypted token first.
    final token = await CredentialsStorage.loadAuthToken();
    if (token != null && token.isNotEmpty) return token;

    // Migration: if a plain-text token exists from an older install, re-save it
    // encrypted and remove the plain-text copy.
    final prefs = await SharedPreferences.getInstance();
    final plain = prefs.getString(_keyAuthData);
    if (plain != null && plain.isNotEmpty) {
      await CredentialsStorage.saveAuthToken(plain);
      await prefs.remove(_keyAuthData);
      return plain;
    }
    return null;
  }

  static Future<void> saveAuthData(String authData) async {
    await CredentialsStorage.saveAuthToken(authData);
    // Remove any lingering plain-text copy.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthData);
  }

  static Future<void> clearAuthData() async {
    await CredentialsStorage.clearAuthToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthData);
  }
}

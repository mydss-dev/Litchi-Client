import 'package:shared_preferences/shared_preferences.dart';

import '../models/api_models.dart';

abstract final class RegisterConfigCache {
  static const _keyApiBase = 'register_config_api_base';
  static const _keyEmailSuffixes = 'register_config_email_suffixes';
  static const _keyEmailVerifyRequired =
      'register_config_email_verify_required';

  static Future<RegisterConfig?> load(String apiBase) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyApiBase) != apiBase) return null;

    return RegisterConfig(
      emailSuffixes: prefs.getStringList(_keyEmailSuffixes) ?? const [],
      emailVerifyRequired: prefs.getBool(_keyEmailVerifyRequired) ?? false,
    );
  }

  static Future<void> save(String apiBase, RegisterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiBase, apiBase);
    await prefs.setStringList(_keyEmailSuffixes, config.emailSuffixes);
    await prefs.setBool(
      _keyEmailVerifyRequired,
      config.emailVerifyRequired,
    );
  }
}

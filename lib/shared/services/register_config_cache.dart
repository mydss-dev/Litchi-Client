import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import '../models/api_models.dart';

abstract final class RegisterConfigCache {
  static String get _keyApiBase =>
      AppIdentity.preferenceKey('register_config_api_base');
  static String get _keyEmailSuffixes =>
      AppIdentity.preferenceKey('register_config_email_suffixes');
  static String get _keyEmailVerifyRequired =>
      AppIdentity.preferenceKey('register_config_email_verify_required');
  static String get _keyRegisterOpen =>
      AppIdentity.preferenceKey('register_config_register_open');

  static Future<RegisterConfig?> load(String apiBase) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_keyApiBase) != apiBase) return null;

    return RegisterConfig(
      emailSuffixes: prefs.getStringList(_keyEmailSuffixes) ?? const [],
      emailVerifyRequired: prefs.getBool(_keyEmailVerifyRequired) ?? false,
      // Old cache entries predate this key and retain the historical default.
      registerOpen: prefs.getBool(_keyRegisterOpen) ?? true,
    );
  }

  static Future<void> save(String apiBase, RegisterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiBase, apiBase);
    await prefs.setStringList(_keyEmailSuffixes, config.emailSuffixes);
    await prefs.setBool(_keyEmailVerifyRequired, config.emailVerifyRequired);
    await prefs.setBool(_keyRegisterOpen, config.registerOpen);
  }
}

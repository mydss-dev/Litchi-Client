import 'package:flutter/widgets.dart';

enum AppLocalePreference {
  system,
  simplifiedChinese,
  traditionalChinese,
  english;

  String get storageKey => switch (this) {
    AppLocalePreference.system => 'system',
    AppLocalePreference.simplifiedChinese => 'zh_CN',
    AppLocalePreference.traditionalChinese => 'zh_TW',
    AppLocalePreference.english => 'en',
  };

  Locale? get locale => switch (this) {
    AppLocalePreference.system => null,
    AppLocalePreference.simplifiedChinese => const Locale('zh', 'CN'),
    AppLocalePreference.traditionalChinese => const Locale('zh', 'TW'),
    AppLocalePreference.english => const Locale('en'),
  };

  static AppLocalePreference fromStorage(String? value) => switch (value) {
    'zh_CN' || '简体中文' => AppLocalePreference.simplifiedChinese,
    'zh_TW' || '繁體中文' => AppLocalePreference.traditionalChinese,
    'en' || 'English' => AppLocalePreference.english,
    _ => AppLocalePreference.system,
  };
}

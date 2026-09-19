import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/register_config_cache.dart';
import 'package:litchi_client/shared/services/registration_email_policy.dart';

void main() {
  group('registration email suffix whitelist', () {
    test('empty whitelist leaves email validation to the backend', () {
      expect(RegistrationEmailPolicy.allows('any@example.net', const []), isTrue);
    });

    test('matches normal domains exactly, ignoring case and outer whitespace', () {
      const suffixes = [' gmail.com ', '@QQ.COM'];
      expect(RegistrationEmailPolicy.allows(' Test@GMAIL.Com ', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('test@qq.com', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('test@mail.gmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('test@mail.qq.com', suffixes), isFalse);
    });

    test('rejects lookalike domains and malformed email addresses', () {
      const suffixes = ['gmail.com'];
      expect(RegistrationEmailPolicy.allows('user@evilgmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('user@gmail.com.evil.net', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('usergmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('user@@gmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('user@gmail.com ', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('user@gmail.com other', suffixes), isFalse);
    });

    test('explicit wildcard rules are distinct from exact email domains', () {
      expect(RegistrationEmailPolicy.allows('a@university.edu', const ['.edu']), isTrue);
      expect(RegistrationEmailPolicy.allows('a@sub.example.org', const ['*.example.org']), isTrue);
      expect(RegistrationEmailPolicy.allows('a@example.org', const ['*.example.org']), isFalse);
    });

    test('suffix dropdown contains only usable domains, without duplicates', () {
      expect(RegistrationEmailPolicy.getSelectableDomains(
        const ['@GMAIL.COM', ' gmail.com ', 'qq.com', '*.example.org', '.edu']),
        ['gmail.com', 'qq.com']);
    });
  });

  group('cached registration config', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists verification, whitelist and closed registration', () async {
      const config = RegisterConfig(
        emailSuffixes: ['@gmail.com'],
        emailVerifyRequired: true,
        registerOpen: false,
      );
      await RegisterConfigCache.save('https://one.example', config);
      final restored = await RegisterConfigCache.load('https://one.example');
      expect(restored?.emailSuffixes, ['@gmail.com']);
      expect(restored?.emailVerifyRequired, isTrue);
      expect(restored?.registerOpen, isFalse);
      expect(await RegisterConfigCache.load('https://other.example'), isNull);
    });

    test('preserves legacy default for cache entries without register flag', () async {
      await RegisterConfigCache.save('https://one.example',
          const RegisterConfig(emailVerifyRequired: false));
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((key) =>
          key.endsWith('register_config_register_open')).toList()) {
        await prefs.remove(key);
      }
      expect((await RegisterConfigCache.load('https://one.example'))?.registerOpen,
          isTrue);
    });
  });
}

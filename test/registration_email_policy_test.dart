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

    test('accepts listed domains without case or whitespace sensitivity', () {
      const suffixes = [' gmail.com ', '@QQ.COM'];
      expect(RegistrationEmailPolicy.allows(' Test@GMAIL.Com ', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('test@qq.com', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('test@mail.gmail.com', suffixes), isTrue);
    });

    test('does not accept lookalike suffixes or malformed email addresses', () {
      const suffixes = ['gmail.com'];
      expect(RegistrationEmailPolicy.allows('user@evilgmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('user@gmail.com.evil.net', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('usergmail.com', suffixes), isFalse);
      expect(RegistrationEmailPolicy.allows('user@@gmail.com', suffixes), isFalse);
    });

    test('explicit @ rules require an exact domain', () {
      const suffixes = ['@gmail.com'];
      expect(RegistrationEmailPolicy.allows('a@gmail.com', suffixes), isTrue);
      expect(RegistrationEmailPolicy.allows('a@mail.gmail.com', suffixes), isFalse);
    });

    test('supports extension and wildcard-domain suffix entries', () {
      expect(RegistrationEmailPolicy.allows('a@university.edu', const ['.edu']), isTrue);
      expect(RegistrationEmailPolicy.allows('a@sub.example.org', const ['*.example.org']), isTrue);
      expect(RegistrationEmailPolicy.allows('a@example.org', const ['*.example.org']), isFalse);
    });
  });

  group('cached registration config', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists email verification, whitelist and closed registration', () async {
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

    test('preserves the old default for cache entries without the new flag', () async {
      await RegisterConfigCache.save('https://one.example',
          const RegisterConfig(emailVerifyRequired: false));
      final prefs = await SharedPreferences.getInstance();
      // Model a pre-migration entry by removing only the new field.
      for (final key in prefs.getKeys().where((key) =>
          key.endsWith('register_config_register_open')).toList()) {
        await prefs.remove(key);
      }
      expect((await RegisterConfigCache.load('https://one.example'))?.registerOpen,
          isTrue);
    });
  });
}

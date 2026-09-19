import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import '../models/app_models.dart';
import 'credentials_storage.dart';
import 'protected_cache_cleanup.dart';

/// Small, session-bound cache for the values rendered on the home screen.
///
/// This is deliberately separate from the node cache: it contains no token,
/// subscription URL, or proxy credentials. Account details are still private,
/// so the payload must be protected, not merely bound to an auth fingerprint.
class AccountSummaryCache {
  const AccountSummaryCache({
    required this.user,
    required this.traffic,
    this.aliveIp,
    this.deviceLimit,
    this.resetDay,
    this.expiredAt,
  });

  final UserModel user;
  final TrafficModel traffic;
  final int? aliveIp;
  final int? deviceLimit;
  final int? resetDay;
  final int? expiredAt;

  static String get _key =>
      AppIdentity.preferenceKey('account_summary_cache_v1');
  static const String _secureSlot = 'secure_account_summary_cache';

  static Future<AccountSummaryCache?> load(String authData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null || stored.isEmpty) return null;

      // Older releases wrote plaintext JSON to preferences. Remove insecure
      // content immediately, even if corrupt or belonging to another user.
      // The old P:base64 representation is also not encryption.
      final plainJson = stored.trimLeft().startsWith('{');
      final legacyInsecure = plainJson ||
          stored.startsWith('P:') ||
          stored.startsWith('FB:');
      if (legacyInsecure) await prefs.remove(_key);
      final decoded = plainJson
          ? stored
          : await CredentialsStorage.unprotectString(stored);
      if (decoded == null || decoded.isEmpty) {
        if (!legacyInsecure) await prefs.remove(_key);
        return null;
      }
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      if (json['session'] != _fingerprint(authData)) return null;

      if (legacyInsecure) {
        // Migrate only a matching session. Linux has no secure backend, so
        // plaintext is removed and this cache becomes memory-only there.
        final protected = await CredentialsStorage.protectString(
          decoded,
          slot: _secureSlot,
        );
        if (protected != null && protected.isNotEmpty) {
          await prefs.setString(_key, protected);
        }
      }
      final user = json['user'] as Map<String, dynamic>;
      final traffic = json['traffic'] as Map<String, dynamic>;
      return AccountSummaryCache(
        user: UserModel(
          name: user['name'] as String? ?? '',
          plan: user['plan'] as String? ?? '',
          avatarLetter: user['avatarLetter'] as String? ?? '',
          expiry: user['expiry'] as String? ?? '',
          balance: (user['balance'] as num?)?.toDouble() ?? 0,
          remindExpire: user['remindExpire'] as bool? ?? false,
          remindTraffic: user['remindTraffic'] as bool? ?? false,
          autoRenewal: user['autoRenewal'] as bool? ?? false,
        ),
        traffic: TrafficModel(
          totalGb: (traffic['totalGb'] as num?)?.toDouble() ?? 0,
          usedGb: (traffic['usedGb'] as num?)?.toDouble() ?? 0,
          remainGb: (traffic['remainGb'] as num?)?.toDouble() ?? 0,
        ),
        aliveIp: (json['aliveIp'] as num?)?.toInt(),
        deviceLimit: (json['deviceLimit'] as num?)?.toInt(),
        resetDay: (json['resetDay'] as num?)?.toInt(),
        expiredAt: (json['expiredAt'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(
    String authData, {
    required UserModel user,
    required TrafficModel traffic,
    int? aliveIp,
    int? deviceLimit,
    int? resetDay,
    int? expiredAt,
  }) async {
    if (user.name.isEmpty && user.plan.isEmpty && user.expiry.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'session': _fingerprint(authData),
        'user': {
          'name': user.name,
          'plan': user.plan,
          'avatarLetter': user.avatarLetter,
          'expiry': user.expiry,
          'balance': user.balance,
          'remindExpire': user.remindExpire,
          'remindTraffic': user.remindTraffic,
          'autoRenewal': user.autoRenewal,
        },
        'traffic': {
          'totalGb': traffic.totalGb,
          'usedGb': traffic.usedGb,
          'remainGb': traffic.remainGb,
        },
        'aliveIp': aliveIp,
        'deviceLimit': deviceLimit,
        'resetDay': resetDay,
        'expiredAt': expiredAt,
      });
      final protected = await CredentialsStorage.protectString(
        payload,
        slot: _secureSlot,
      );
      if (protected == null || protected.isEmpty) {
        // Never retain a previous plaintext summary on unsupported platforms.
        await prefs.remove(_key);
        return;
      }
      await prefs.setString(_key, protected);
    } catch (_) {
      // Best-effort UI cache: a failed write must not block login or leave
      // a previous plaintext value behind.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_key);
      } catch (_) {}
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Best-effort preference cleanup; still revoke the protected payload.
    }
    try {
      await ProtectedCacheCleanup.deleteSlot(_secureSlot);
    } catch (_) {
      // Logout must not be blocked if the OS key store is unavailable.
    }
  }

  static String _fingerprint(String authData) =>
      sha256.convert(utf8.encode(authData)).toString();
}

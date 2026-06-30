import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_identity.dart';
import '../models/app_models.dart';

/// Small, session-bound cache for the values rendered on the home screen.
///
/// This is deliberately separate from the node cache: it contains no token,
/// subscription URL, or proxy credentials. The auth fingerprint prevents a
/// cached summary from being shown for a different account.
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

  static Future<AccountSummaryCache?> load(String authData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['session'] != _fingerprint(authData)) return null;
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
      await prefs.setString(
        _key,
        jsonEncode({
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
        }),
      );
    } catch (_) {
      // Best-effort UI cache. A failed write must never block login.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  static String _fingerprint(String authData) =>
      sha256.convert(utf8.encode(authData)).toString();
}

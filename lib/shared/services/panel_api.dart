import 'package:dio/dio.dart';

import '../models/api_models.dart';
import 'api_client.dart';
import 'subscription/subscription_parser.dart';


/// Generic subscription panel API client.
///
/// Handles authentication, user data, subscription parsing, plans, invite and
/// traffic — using the V2Board-compatible REST surface that most panels share.
class PanelApi {
  const PanelApi(this._client);

  final ApiClient _client;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<AuthResult> login(String email, String password) async {
    final res = await _client.post('/passport/auth/login', data: {
      'email': email,
      'password': password,
    });
    _check(res);
    return AuthResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? inviteCode,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    if (inviteCode != null && inviteCode.isNotEmpty) {
      body['invite_code'] = inviteCode;
    }
    final res = await _client.post('/passport/auth/register', data: body);
    _check(res);
    return AuthResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post('/user/changePassword', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
      'password_confirmation': passwordConfirmation,
    });
    _check(res);
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<RemoteUser> getUserInfo() async {
    final res = await _client.get('/user/info');
    _check(res);
    return RemoteUser.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Subscription / Nodes ─────────────────────────────────────────────────

  Future<String> getSubscribeUrl() async {
    final res = await _client.get('/user/getSubscribe');
    _check(res);
    final data = res['data'];
    if (data is Map) {
      final url = data['subscribe_url']?.toString() ?? '';
      if (url.isNotEmpty) return url;
    }
    throw const ApiException('无法获取订阅地址');
  }

  /// Fetches [subscribeUrl] and parses the returned node list.
  /// Returns nodes plus optional updated traffic from the subscription-userinfo header.
  Future<SubscriptionResult> fetchSubscription(String subscribeUrl) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        // Neutral UA → panel returns Base64 URI list (default format).
        // UA containing "clash" → panel returns Clash YAML.
        'User-Agent': 'LitchiClient/1.0',
      },
    ));

    final res = await dio.get<String>(
      subscribeUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final body = (res.data ?? '').trim();

    SubTraffic? traffic;
    final userinfo = res.headers.value('subscription-userinfo');
    if (userinfo != null) traffic = SubTraffic.fromHeader(userinfo);

    if (body.isEmpty) return SubscriptionResult(nodes: [], traffic: traffic);

    final nodes = SubscriptionParser.parse(body);
    return SubscriptionResult(nodes: nodes, traffic: traffic);
  }

  // ── Plans ─────────────────────────────────────────────────────────────────

  Future<List<RemotePlan>> getPlans() async {
    final res = await _client.get('/user/plan/fetch');
    _check(res);
    final list = res['data'] as List? ?? [];
    return list.map((e) => RemotePlan.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Invite ────────────────────────────────────────────────────────────────

  Future<RemoteInvite> getInviteInfo() async {
    final res = await _client.get('/user/invite/fetch');
    _check(res);
    return RemoteInvite.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Traffic ───────────────────────────────────────────────────────────────

  Future<List<RemoteTrafficLog>> getTrafficLog() async {
    final res = await _client.get('/user/stat/getTrafficLog');
    _check(res);
    final list = res['data'] as List? ?? [];
    return list
        .map((e) => RemoteTrafficLog.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Order ─────────────────────────────────────────────────────────────────

  Future<String> getCommCurrencySymbol() async {
    try {
      final res = await _client.get('/user/comm/config');
      _check(res);
      return (res['data'] as Map?)?['currency_symbol']?.toString() ?? '¥';
    } catch (_) {
      return '¥';
    }
  }

  Future<CouponResult?> verifyCoupon(String code, int planId) async {
    final res = await _client.post('/user/coupon/check', data: {
      'code': code,
      'plan_id': planId,
    });
    _check(res);
    if (res['data'] == null) return null;
    return CouponResult.fromJson(res['data'] as Map<String, dynamic>);
  }

  Future<String> submitOrder({
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    final data = <String, dynamic>{'plan_id': planId, 'period': period};
    if (couponCode != null && couponCode.isNotEmpty) {
      data['coupon_code'] = couponCode;
    }
    final res = await _client.post('/user/order/save', data: data);
    _check(res);
    return res['data']?.toString() ?? '';
  }

  Future<List<RemotePaymentMethod>> getPaymentMethods() async {
    final res = await _client.get('/user/order/getPaymentMethod');
    _check(res);
    final list = res['data'] as List? ?? [];
    return list
        .map((e) => RemotePaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a redirect URL. Empty string means checkout was handled
  /// server-side (e.g. balance deduction) — poll order status.
  Future<String> checkoutOrder(String tradeNo, int methodId) async {
    final res = await _client.post('/user/order/checkout', data: {
      'trade_no': tradeNo,
      'method': methodId,
    });
    _check(res);
    return res['data']?.toString() ?? '';
  }

  /// Status: 0=pending, 1=processing, 2=cancelled, 3=complete, 4=refunded.
  Future<int> checkOrderStatus(String tradeNo) async {
    final res = await _client.get(
      '/user/order/check',
      params: {'trade_no': tradeNo},
    );
    _check(res);
    return (res['data'] as num?)?.toInt() ?? 0;
  }

  void _check(Map<String, dynamic> res) {
    final code = res['code'];
    if (code != 0 && code != null) {
      throw ApiException(res['message']?.toString() ?? '请求失败');
    }
  }
}

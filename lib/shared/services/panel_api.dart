import 'package:dio/dio.dart';

import '../models/api_models.dart';
import 'api_client.dart';
import 'subscription_parser.dart';

/// Generic subscription panel API client.
///
/// Handles authentication, user data, subscription parsing, plans, invite and
/// traffic — using the V2Board-compatible REST surface that most panels share.
class PanelApi {
  const PanelApi(this._client);

  final ApiClient _client;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<AuthResult> login(String email, String password) async {
    final res = await _client.post(
      '/passport/auth/login',
      data: {'email': email, 'password': password},
    );
    _check(res);
    return AuthResult.fromJson(_dataMap(res));
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? inviteCode,
    String? emailCode,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    if (inviteCode != null && inviteCode.isNotEmpty) {
      body['invite_code'] = inviteCode;
    }
    if (emailCode != null && emailCode.isNotEmpty) {
      body['email_code'] = emailCode;
    }
    final res = await _client.post('/passport/auth/register', data: body);
    _check(res);
    return AuthResult.fromJson(_dataMap(res));
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post(
      '/user/changePassword',
      data: {
        'old_password': oldPassword,
        'new_password': newPassword,
        'password_confirmation': passwordConfirmation,
      },
    );
    _check(res);
  }

  // ── Password reset ────────────────────────────────────────────────────────

  /// Sends a verification code to [email] for password reset.
  Future<void> sendEmailVerify(String email) async {
    final res = await _client.post(
      '/passport/comm/sendEmailVerify',
      data: {'email': email},
    );
    _check(res);
  }

  /// Resets the password using the emailed verification code.
  Future<void> updateUserSettings({
    required bool remindExpire,
    required bool remindTraffic,
    required bool autoRenewal,
  }) async {
    final res = await _client.post(
      '/user/update',
      data: {
        'remind_expire': remindExpire ? 1 : 0,
        'remind_traffic': remindTraffic ? 1 : 0,
        'auto_renewal': autoRenewal ? 1 : 0,
      },
    );
    _check(res);
  }

  Future<void> resetPassword({
    required String email,
    required String emailCode,
    required String password,
    required String passwordConfirmation,
  }) async {
    final res = await _client.post(
      '/passport/auth/forget',
      data: {
        'email': email,
        'email_code': emailCode,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
    _check(res);
  }

  // ── Guest config ─────────────────────────────────────────────────────────

  /// Returns registration config from the panel (email suffixes + verify flag).
  /// Never throws — returns safe defaults on failure.
  Future<RegisterConfig> getRegisterConfig() async {
    try {
      final res = await _client.get('/guest/comm/config');
      final data = res['data'];
      if (data is Map) {
        final suffixes =
            (data['email_whitelist_suffix'] as List?)
                ?.whereType<String>()
                .where((s) => s.isNotEmpty)
                .toList() ??
            [];
        final v = data['is_email_verify'];
        final verifyRequired = v == 1 || v == true;
        return RegisterConfig(
          emailSuffixes: suffixes,
          emailVerifyRequired: verifyRequired,
        );
      }
      return const RegisterConfig();
    } catch (_) {
      return const RegisterConfig();
    }
  }

  // ── User ──────────────────────────────────────────────────────────────────

  Future<List<RemoteLoginLog>> getLoginLogs() async {
    try {
      final res = await _client.get('/user/login/log');
      _check(res);
      return _dataList(res).map(RemoteLoginLog.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RemoteUser> getUserInfo() async {
    final res = await _client.get('/user/info');
    _check(res);
    return RemoteUser.fromJson(_dataMap(res));
  }

  // ── Subscription / Nodes ─────────────────────────────────────────────────

  Future<String> getSubscribeUrl() async {
    final info = await getSubscribeInfo();
    if (info.subscribeUrl.isNotEmpty) return info.subscribeUrl;
    throw const ApiException('无法获取订阅地址');
  }

  Future<RemoteSubscribe> getSubscribeInfo() async {
    final res = await _client.get('/user/getSubscribe');
    _check(res);
    final data = res['data'];
    if (data is Map) {
      return RemoteSubscribe.fromJson(Map<String, dynamic>.from(data));
    }
    throw const ApiException('无法获取订阅信息');
  }

  /// Fetches [subscribeUrl] and parses the returned node list.
  /// Returns nodes plus optional updated traffic from the subscription-userinfo header.
  Future<SubscriptionResult> fetchSubscription(String subscribeUrl) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          // Neutral UA → panel returns Base64 URI list (default format).
          // UA containing "clash" → panel returns Clash YAML.
          'User-Agent': 'LitchiClient/1.0',
        },
      ),
    );

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
    return _dataList(res).map(RemotePlan.fromJson).toList();
  }

  // ── Invite ────────────────────────────────────────────────────────────────

  Future<RemoteInvite> getInviteInfo() async {
    final res = await _client.get('/user/invite/fetch');
    _check(res);
    final data = res['data'];
    if (data is Map<String, dynamic>) return RemoteInvite.fromJson(data);
    if (data is Map) {
      return RemoteInvite.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is List) return RemoteInvite.fromJson({'codes': data});
    throw const ApiException('服务器返回数据格式异常');
  }

  Future<void> createInviteCode() async {
    final res = await _client.get('/user/invite/save');
    _check(res);
  }

  Future<List<RemoteInviteRecord>> getInviteDetails({
    int current = 1,
    int pageSize = 10,
  }) async {
    final res = await _client.get(
      '/user/invite/details',
      params: {'current': current, 'page_size': pageSize},
    );
    _check(res);
    return _dataList(res).map(RemoteInviteRecord.fromJson).toList();
  }

  Future<RemoteCommConfig> getCommConfig() async {
    final res = await _client.get('/user/comm/config');
    _check(res);
    return RemoteCommConfig.fromJson(_dataMap(res));
  }

  Future<void> transferCommission(int amountCents) async {
    final res = await _client.post(
      '/user/transfer',
      data: {'transfer_amount': amountCents},
    );
    _check(res);
  }

  Future<void> withdrawCommission({
    required int amountCents,
    required String account,
    required String method,
  }) async {
    final res = await _client.post(
      '/user/ticket/withdraw',
      data: {
        'withdraw_amount': amountCents,
        'withdraw_account': account,
        'withdraw_method': method,
      },
    );
    _check(res);
  }

  // ── Traffic ───────────────────────────────────────────────────────────────

  Future<List<RemoteTrafficLog>> getTrafficLog() async {
    final res = await _client.get('/user/stat/getTrafficLog');
    _check(res);
    return _dataList(res).map(RemoteTrafficLog.fromJson).toList();
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
    final res = await _client.post(
      '/user/coupon/check',
      data: {'code': code, 'plan_id': planId},
    );
    _check(res);
    if (res['data'] == null) return null;
    return CouponResult.fromJson(_dataMap(res));
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

  /// Creates a wallet top-up order. [amountCents] is the amount in cents (fen).
  /// Returns the trade_no for the subsequent checkout call.
  Future<String> submitRechargeOrder(int amountCents) async {
    final res = await _client.post(
      '/user/order/save',
      data: {'period': 'deposit', 'deposit_amount': amountCents, 'plan_id': 0},
    );
    _check(res);
    return res['data']?.toString() ?? '';
  }

  Future<List<RemotePaymentMethod>> getPaymentMethods() async {
    final res = await _client.get('/user/order/getPaymentMethod');
    _check(res);
    return _dataList(res).map(RemotePaymentMethod.fromJson).toList();
  }

  /// Returns checkout result with URL and type.
  /// type=0: QR code content — encode as QR.
  /// type=1: Redirect URL — open in browser.
  /// Empty URL means balance deduction — poll for completion.
  Future<CheckoutResult> checkoutOrder(String tradeNo, int methodId) async {
    final res = await _client.post(
      '/user/order/checkout',
      data: {'trade_no': tradeNo, 'method': methodId},
    );
    _check(res);
    final url = res['data']?.toString() ?? '';
    final type = (res['type'] as num?)?.toInt() ?? 0;
    return CheckoutResult(url, type);
  }

  Future<List<RemoteOrder>> fetchOrders() async {
    final res = await _client.get('/user/order/fetch');
    _check(res);
    return _dataList(res).map(RemoteOrder.fromJson).toList();
  }

  Future<void> cancelOrder(String tradeNo) async {
    final res = await _client.post(
      '/user/order/cancel',
      data: {'trade_no': tradeNo},
    );
    _check(res);
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

  // ── Notices ───────────────────────────────────────────────────────────────

  /// Returns all announcements. Never throws — returns empty list on failure.
  Future<List<NoticeModel>> getNotices() async {
    try {
      final res = await _client.get('/user/notice/fetch');
      _check(res);
      final list = res['data'] as List? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(NoticeModel.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Tickets ───────────────────────────────────────────────────────────────

  Future<List<TicketModel>> getTickets() async {
    final res = await _client.get('/user/ticket/fetch');
    _check(res);
    final list = res['data'] as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(TicketModel.fromJson)
        .toList();
  }

  Future<TicketModel> getTicketDetail(int ticketId) async {
    final res = await _client.get(
      '/user/ticket/fetch',
      params: {'id': ticketId},
    );
    _check(res);
    final data = res['data'];
    if (data is Map<String, dynamic>) return TicketModel.fromJson(data);
    throw const ApiException('无法获取工单详情');
  }

  Future<void> createTicket({
    required String subject,
    required int level,
    required String message,
  }) async {
    final res = await _client.post(
      '/user/ticket/save',
      data: {'subject': subject, 'level': level, 'message': message},
    );
    _check(res);
  }

  Future<void> replyTicket({
    required int ticketId,
    required String message,
  }) async {
    final res = await _client.post(
      '/user/ticket/reply',
      data: {'id': ticketId, 'message': message},
    );
    _check(res);
  }

  Future<void> closeTicket(int ticketId) async {
    final res = await _client.post(
      '/user/ticket/close',
      data: {'id': ticketId},
    );
    _check(res);
  }

  void _check(Map<String, dynamic> res) {
    final code = res['code'];
    if (code != 0 && code != null) {
      throw ApiException(extractApiErrorMessage(res) ?? '请求失败');
    }
  }

  /// Safely extracts `data` as an object. Throws a readable [ApiException]
  /// instead of a raw cast crash when the backend shape changes.
  static Map<String, dynamic> _dataMap(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException('服务器返回数据格式异常');
  }

  /// Safely extracts `data` as a list of objects, skipping malformed items.
  static List<Map<String, dynamic>> _dataList(Map<String, dynamic> res) {
    final data = res['data'];
    if (data is! List) return const [];
    return data
        .map(
          (e) => e is Map<String, dynamic>
              ? e
              : (e is Map ? Map<String, dynamic>.from(e) : null),
        )
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}

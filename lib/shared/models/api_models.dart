// Remote API response types. Separate from app_models.dart (UI view models).
// These types are panel-agnostic and do not reference any specific backend.

class AuthResult {
  final String authData;
  final bool isAdmin;

  const AuthResult({required this.authData, required this.isAdmin});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final authData =
        json['auth_data']?.toString() ?? json['token']?.toString() ?? '';
    return AuthResult(
      authData: authData,
      isAdmin: (json['is_admin'] as int? ?? 0) == 1,
    );
  }
}

class RemoteUser {
  final int id;
  final String email;
  final int? expiredAt; // unix timestamp; null = permanent
  final double balance; // cents
  final double transferEnable; // GB
  final double used; // bytes (upload + download combined)
  final int subscribeStatus; // 0=normal 1=expired 2=banned
  final int? planId;
  final String planName;
  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;

  const RemoteUser({
    required this.id,
    required this.email,
    this.expiredAt,
    required this.balance,
    required this.transferEnable,
    required this.used,
    required this.subscribeStatus,
    this.planId,
    this.planName = '',
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
  });

  factory RemoteUser.fromJson(Map<String, dynamic> json) {
    final usedRaw = json['used'] ?? json['u'];
    final planMap = _map(json['plan']);
    final subscribeMap = _map(json['subscribe']);
    return RemoteUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      expiredAt: (json['expired_at'] as num?)?.toInt(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      transferEnable: (json['transfer_enable'] as num?)?.toDouble() ?? 0,
      used: (usedRaw as num?)?.toDouble() ?? 0,
      subscribeStatus: (json['subscribe_status'] as num?)?.toInt() ?? 0,
      planId:
          _int(json['plan_id']) ??
          _int(json['planId']) ??
          _int(json['current_plan_id']) ??
          _int(json['currentPlanId']) ??
          _int(planMap?['id']) ??
          _int(json['plan']),
      planName:
          _firstString(json, [
            'plan_name',
            'planName',
            'plan_title',
            'planTitle',
            'product_name',
            'productName',
          ]) ??
          _firstString(planMap, ['name', 'title']) ??
          _firstString(subscribeMap, [
            'plan_name',
            'planName',
            'name',
            'title',
          ]) ??
          '',
      remindExpire: _bool(json['remind_expire']),
      remindTraffic: _bool(json['remind_traffic']),
      autoRenewal: _bool(json['auto_renewal']),
    );
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static String? _firstString(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return null;
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  String get expiryDisplay {
    if (expiredAt == null || expiredAt == 0) return '永久';
    final dt = DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  String get planLabel {
    final name = planName.trim();
    if (name.isNotEmpty) return name;
    if (subscribeStatus == 1) return '已到期';
    return '';
  }
}

class RemoteNode {
  final int id;
  final String name;
  final double rate;
  final String server; // hostname / IP
  final int port; // TCP port (0 = unknown)

  /// Original proxy URI (vmess://, vless://, trojan://, ss://, hy2://).
  /// Empty for nodes parsed from Clash YAML without URI reconstruction.
  final String rawUri;

  /// Original Clash proxy object for YAML subscriptions. This preserves the
  /// protocol-specific fields from a native Clash subscription entry.
  final Map<String, dynamic>? rawOutbound;

  const RemoteNode({
    required this.id,
    required this.name,
    required this.rate,
    this.server = '',
    this.port = 0,
    this.rawUri = '',
    this.rawOutbound,
  });

  factory RemoteNode.fromJson(Map<String, dynamic> json) {
    return RemoteNode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '未知节点',
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      server: json['server']?.toString() ?? json['add']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
      rawOutbound: json['rawOutbound'] is Map
          ? Map<String, dynamic>.from(json['rawOutbound'] as Map)
          : null,
    );
  }
}

class RemotePlan {
  final int id;
  final String name;
  final String? description;
  final double transferEnable; // bytes
  final int? monthPrice; // cents
  final int? quarterPrice;
  final int? halfYearPrice;
  final int? yearPrice;
  final int? twoYearPrice;
  final int? threeYearPrice;
  final int? onetimePrice;
  final int? deviceLimit;
  final int? capacityLimit;
  final int show;

  const RemotePlan({
    required this.id,
    required this.name,
    this.description,
    required this.transferEnable,
    this.monthPrice,
    this.quarterPrice,
    this.halfYearPrice,
    this.yearPrice,
    this.twoYearPrice,
    this.threeYearPrice,
    this.onetimePrice,
    this.deviceLimit,
    this.capacityLimit,
    required this.show,
  });

  factory RemotePlan.fromJson(Map<String, dynamic> json) {
    return RemotePlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description:
          json['content']?.toString() ?? json['description']?.toString(),
      transferEnable: _number(json['transfer_enable']),
      monthPrice: _int(json, 'month_price'),
      quarterPrice: _int(json, 'quarter_price'),
      halfYearPrice: _int(json, 'half_year_price'),
      yearPrice: _int(json, 'year_price'),
      twoYearPrice: _int(json, 'two_year_price'),
      threeYearPrice: _int(json, 'three_year_price'),
      onetimePrice: _int(json, 'onetime_price'),
      deviceLimit: _int(json, 'device_limit'),
      capacityLimit: _int(json, 'capacity_limit'),
      show: _int(json, 'show') ?? 1,
    );
  }

  String get capacityDisplay {
    if (transferEnable <= 0) return '';
    if (transferEnable >= 1024) {
      return '${(transferEnable / 1024).toStringAsFixed(0)} TB';
    }
    return '${transferEnable.toStringAsFixed(0)} GB';
  }

  static int? _int(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0;
  }
}

class RemoteInvite {
  final String inviteCode;
  final String inviteUrl;
  final List<RemoteInviteCode> codes;
  final double commissionRate;
  final double validCommission; // cents
  final double pendingCommission; // cents
  final double balance; // cents
  final int effectCount;

  const RemoteInvite({
    required this.inviteCode,
    required this.inviteUrl,
    required this.codes,
    required this.commissionRate,
    required this.validCommission,
    required this.pendingCommission,
    required this.balance,
    required this.effectCount,
  });

  factory RemoteInvite.fromJson(Map<String, dynamic> json) {
    final codes = _codes(json);
    final firstCode = codes.isEmpty ? null : codes.first;
    final stat = (json['stat'] as List?) ?? const [];
    return RemoteInvite(
      inviteCode:
          _string(json, ['invite_code', 'code']) ?? firstCode?.code ?? '',
      inviteUrl:
          _string(json, ['invite_url', 'url', 'link']) ?? firstCode?.link ?? '',
      codes: codes,
      commissionRate:
          _num(json, ['commission_rate', 'commissionRate', 'rate']) ??
          _statNum(stat, 3) ??
          0,
      validCommission:
          _num(json, [
            'valid_commission',
            'commission_amount',
            'total_commission',
          ]) ??
          _statNum(stat, 1) ??
          0,
      pendingCommission:
          _num(json, ['pending_commission', 'confirming_commission']) ??
          _statNum(stat, 2) ??
          0,
      balance:
          _num(json, ['balance', 'available_balance', 'pending_amount']) ??
          _statNum(stat, 4) ??
          0,
      effectCount:
          (_num(json, ['effect_count', 'effectCount', 'invite_count']) ??
                  _statNum(stat, 0))
              ?.toInt() ??
          0,
    );
  }

  static List<RemoteInviteCode> _codes(Map<String, dynamic> json) {
    final rawCodes = json['codes'] ?? json['invite_codes'] ?? json['list'];
    if (rawCodes is! List) return const [];
    return rawCodes
        .map((item) {
          if (item is Map) {
            return RemoteInviteCode.fromJson(Map<String, dynamic>.from(item));
          }
          final code = item.toString();
          return code.isEmpty ? null : RemoteInviteCode(code: code, link: '');
        })
        .whereType<RemoteInviteCode>()
        .where((item) => item.code.isNotEmpty)
        .toList();
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static double? _num(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  static double? _statNum(List<dynamic> stat, int index) {
    if (index >= stat.length) return null;
    final value = stat[index];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class RemoteInviteCode {
  const RemoteInviteCode({required this.code, required this.link});

  final String code;
  final String link;

  factory RemoteInviteCode.fromJson(Map<String, dynamic> json) {
    return RemoteInviteCode(
      code: RemoteInvite._string(json, ['invite_code', 'code']) ?? '',
      link: RemoteInvite._string(json, ['invite_url', 'url', 'link']) ?? '',
    );
  }
}

class RemoteInviteRecord {
  const RemoteInviteRecord({
    required this.id,
    required this.tradeNo,
    required this.userName,
    required this.orderAmount,
    required this.commissionAmount,
    required this.createdAt,
  });

  final int id;
  final String tradeNo;
  final String userName;
  final int orderAmount;
  final int commissionAmount;
  final int createdAt;

  factory RemoteInviteRecord.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return RemoteInviteRecord(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tradeNo: json['trade_no']?.toString() ?? '',
      userName: user is Map
          ? (user['email'] ?? user['name'] ?? user['id'] ?? '').toString()
          : '',
      orderAmount: (json['order_amount'] as num?)?.toInt() ?? 0,
      commissionAmount: (json['get_amount'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  String amountDisplay(String symbol) =>
      '$symbol${(orderAmount / 100).toStringAsFixed(2)}';

  String commissionDisplay(String symbol) =>
      '$symbol${(commissionAmount / 100).toStringAsFixed(2)}';

  String get dateDisplay {
    if (createdAt == 0) return '--';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

class RemoteCommConfig {
  const RemoteCommConfig({
    required this.inviteUrlBase,
    required this.currencySymbol,
    required this.withdrawClose,
    required this.withdrawMethods,
    required this.minWithdrawAmount,
  });

  final String inviteUrlBase;
  final String currencySymbol;
  final int withdrawClose;
  final List<String> withdrawMethods;
  final double minWithdrawAmount; // cents

  factory RemoteCommConfig.fromJson(Map<String, dynamic> json) {
    return RemoteCommConfig(
      inviteUrlBase: _inviteUrlBase(json),
      currencySymbol:
          _string(json, ['currency_symbol', 'currencySymbol']) ?? '¥',
      withdrawClose: _int(json['withdraw_close']) ?? 1,
      withdrawMethods: _stringList(json['withdraw_methods']),
      minWithdrawAmount:
          _num(json, ['min_withdraw_amount', 'minWithdrawAmount']) ?? 0,
    );
  }

  static String _inviteUrlBase(Map<String, dynamic> json) {
    final direct = _string(json, [
      'invite_url_base',
      'invite_base_url',
      'invite_url',
      'frontend_url',
      'site_url',
      'custom_domain',
      'customDomain',
    ]);
    if (direct != null) return direct;

    final inviteLinkConfig =
        json['inviteLinkConfig'] ?? json['invite_link_config'];
    if (inviteLinkConfig is Map) {
      final map = Map<String, dynamic>.from(inviteLinkConfig);
      final mode = _string(map, ['linkMode', 'link_mode']);
      final customDomain = _string(map, ['customDomain', 'custom_domain']);
      if (mode == 'custom' && customDomain != null) return customDomain;
    }

    return '';
  }

  static String? _string(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static int? _int(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _num(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class RemoteTrafficLog {
  final DateTime date;
  final double upload; // bytes
  final double download; // bytes
  final double serverRate;
  final double traffic; // bytes, rate-adjusted when possible

  const RemoteTrafficLog({
    required this.date,
    required this.upload,
    required this.download,
    required this.serverRate,
    required this.traffic,
  });

  factory RemoteTrafficLog.fromJson(Map<String, dynamic> json) {
    final recordAt = (json['record_at'] as num?)?.toInt();
    final dateText = json['date']?.toString() ?? '';
    final parsedDate = recordAt != null
        ? DateTime.fromMillisecondsSinceEpoch(recordAt * 1000)
        : DateTime.tryParse(dateText) ?? DateTime.now();
    final upload = (json['u'] as num?)?.toDouble() ?? 0;
    final download = (json['d'] as num?)?.toDouble() ?? 0;
    final serverRate =
        double.tryParse(json['server_rate']?.toString() ?? '') ?? 1;
    final traffic =
        (json['traffic'] as num?)?.toDouble() ??
        (upload + download) * serverRate;
    return RemoteTrafficLog(
      date: parsedDate,
      upload: upload,
      download: download,
      serverRate: serverRate,
      traffic: traffic,
    );
  }
}

class RemoteSubscribe {
  final String subscribeUrl;
  final double transferEnable; // bytes
  final double upload; // bytes
  final double download; // bytes
  final int? expiredAt; // unix timestamp
  final int? resetDay;
  final int? deviceLimit;
  final int? aliveIp;

  const RemoteSubscribe({
    required this.subscribeUrl,
    required this.transferEnable,
    required this.upload,
    required this.download,
    this.expiredAt,
    this.resetDay,
    this.deviceLimit,
    this.aliveIp,
  });

  factory RemoteSubscribe.fromJson(Map<String, dynamic> json) {
    return RemoteSubscribe(
      subscribeUrl: json['subscribe_url']?.toString() ?? '',
      transferEnable: (json['transfer_enable'] as num?)?.toDouble() ?? 0,
      upload: (json['u'] as num?)?.toDouble() ?? 0,
      download: (json['d'] as num?)?.toDouble() ?? 0,
      expiredAt: (json['expired_at'] as num?)?.toInt(),
      resetDay: (json['reset_day'] as num?)?.toInt(),
      deviceLimit: (json['device_limit'] as num?)?.toInt(),
      aliveIp: (json['alive_ip'] as num?)?.toInt(),
    );
  }
}

/// Traffic info parsed from subscription-userinfo response header.
class SubTraffic {
  final double upload; // bytes
  final double download; // bytes
  final double total; // bytes
  final int? expire; // unix timestamp

  const SubTraffic({
    required this.upload,
    required this.download,
    required this.total,
    this.expire,
  });

  /// Parses "upload=X; download=X; total=X; expire=X"
  factory SubTraffic.fromHeader(String header) {
    double upload = 0, download = 0, total = 0;
    int? expire;
    for (final part in header.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final k = kv[0].trim();
      final v = kv[1].trim();
      switch (k) {
        case 'upload':
          upload = double.tryParse(v) ?? 0;
          break;
        case 'download':
          download = double.tryParse(v) ?? 0;
          break;
        case 'total':
          total = double.tryParse(v) ?? 0;
          break;
        case 'expire':
          expire = int.tryParse(v);
          break;
      }
    }
    return SubTraffic(
      upload: upload,
      download: download,
      total: total,
      expire: expire,
    );
  }
}

/// Result of fetching and parsing a subscription URL.
class SubscriptionResult {
  final List<RemoteNode> nodes;
  final SubTraffic? traffic; // null if header absent
  final List<String> rules;
  final Map<String, dynamic>
  ruleProviders; // rule-provider name → {type, url, …}

  const SubscriptionResult({
    required this.nodes,
    this.traffic,
    this.rules = const [],
    this.ruleProviders = const {},
  });
}

/// Full profile parsed from a subscription (Clash YAML or URI list).
class ParsedSubscriptionProfile {
  const ParsedSubscriptionProfile({
    required this.nodes,
    this.rules = const [],
    this.ruleProviders = const {},
  });

  final List<RemoteNode> nodes;
  final List<String> rules;
  final Map<String, dynamic> ruleProviders;
}

class RemotePaymentMethod {
  final int id;
  final String name;
  final String? iconUrl;
  final int? handlingFeeFixed; // cents
  final double? handlingFeePercent; // e.g. 2.5 = 2.5%

  const RemotePaymentMethod({
    required this.id,
    required this.name,
    this.iconUrl,
    this.handlingFeeFixed,
    this.handlingFeePercent,
  });

  factory RemotePaymentMethod.fromJson(Map<String, dynamic> json) {
    return RemotePaymentMethod(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      iconUrl: json['icon']?.toString(),
      handlingFeeFixed: (json['handling_fee_fixed'] as num?)?.toInt(),
      handlingFeePercent: (json['handling_fee_percent'] as num?)?.toDouble(),
    );
  }

  int feeForAmount(int amountCents) {
    final fixed = handlingFeeFixed ?? 0;
    final percent = handlingFeePercent ?? 0;
    return fixed + (amountCents * percent / 100).round();
  }
}

class CouponResult {
  final String name;
  final int type; // 1 = fixed deduction (cents), 2 = percent off
  final int value;

  const CouponResult({
    required this.name,
    required this.type,
    required this.value,
  });

  factory CouponResult.fromJson(Map<String, dynamic> json) {
    return CouponResult(
      name: json['name']?.toString() ?? '',
      type: (json['type'] as num?)?.toInt() ?? 1,
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A single order from /user/order/fetch.
/// status: 0=pending 1=processing 2=cancelled 3=complete 4=discounted
class RemoteOrder {
  final String tradeNo;
  final String? planName;
  final String period;
  final int totalAmount; // cents
  final int status;
  final int createdAt; // unix timestamp (seconds)

  const RemoteOrder({
    required this.tradeNo,
    this.planName,
    required this.period,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
  });

  factory RemoteOrder.fromJson(Map<String, dynamic> json) {
    return RemoteOrder(
      tradeNo: json['trade_no']?.toString() ?? '',
      planName: json['plan_name']?.toString(),
      period: json['period']?.toString() ?? '',
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
    );
  }

  String get statusLabel => switch (status) {
    0 => '待支付',
    1 => '处理中',
    2 => '已取消',
    3 => '已完成',
    4 => '已折抵',
    _ => '未知',
  };

  String get periodLabel => switch (period) {
    'month_price' => '月付',
    'quarter_price' => '季付',
    'half_year_price' => '半年付',
    'year_price' => '年付',
    'two_year_price' => '两年付',
    'three_year_price' => '三年付',
    'onetime_price' => '买断',
    _ => period,
  };

  String amountDisplay(String currencySymbol) {
    final yuan = totalAmount / 100.0;
    return '$currencySymbol${yuan.toStringAsFixed(2)}';
  }

  String get dateDisplay {
    if (createdAt == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

/// Detailed payment amounts returned by GET /user/order/detail.
///
/// Some V2Board-compatible backends reserve account balance while creating an
/// order and expose that deduction as [balanceAmount]. A null value means the
/// backend does not advertise this capability; zero means it is supported but
/// no balance was used for this order.
class RemoteOrderPaymentDetail {
  const RemoteOrderPaymentDetail({
    required this.totalAmount,
    required this.discountAmount,
    required this.surplusAmount,
    required this.balanceAmount,
    required this.refundAmount,
    required this.preHandlingAmount,
    required this.status,
  });

  final int? totalAmount; // remaining amount due, in cents
  final int? discountAmount; // coupon / promotion discount, in cents
  final int? surplusAmount; // old subscription credit, in cents
  final int? balanceAmount; // reserved balance, in cents
  final int? refundAmount; // amount returned by a plan change, in cents
  final int? preHandlingAmount; // backend-estimated payment fee, in cents
  final int status;

  bool get usedBalance => (balanceAmount ?? 0) > 0;
  bool get balanceOnly =>
      usedBalance && totalAmount != null && totalAmount! <= 0;

  factory RemoteOrderPaymentDetail.fromJson(Map<String, dynamic> json) {
    return RemoteOrderPaymentDetail(
      totalAmount: json.containsKey('total_amount')
          ? (json['total_amount'] as num?)?.toInt()
          : null,
      discountAmount: json.containsKey('discount_amount')
          ? (json['discount_amount'] as num?)?.toInt() ?? 0
          : null,
      surplusAmount: json.containsKey('surplus_amount')
          ? (json['surplus_amount'] as num?)?.toInt() ?? 0
          : null,
      balanceAmount: json.containsKey('balance_amount')
          ? (json['balance_amount'] as num?)?.toInt() ?? 0
          : null,
      refundAmount: json.containsKey('refund_amount')
          ? (json['refund_amount'] as num?)?.toInt() ?? 0
          : null,
      preHandlingAmount: json.containsKey('pre_handling_amount')
          ? (json['pre_handling_amount'] as num?)?.toInt() ?? 0
          : null,
      status: (json['status'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result from POST /user/order/checkout.
/// type=0: [url] is QR code content (WeChat/Alipay scheme) — show as QR.
/// type=1: [url] is a web redirect link — open in browser and optionally show QR.
/// Empty [url] means no external payment page was created (commonly a balance
/// checkout); callers must still verify the order status before showing success.
class CheckoutResult {
  const CheckoutResult(this.url, this.type);
  final String url;
  final int type; // 0 = qr, 1 = redirect link
}

/// A single entry from GET /user/login/log.
/// [remind] = true means the backend flagged this login as suspicious.
class RemoteLoginLog {
  final String ip;
  final int createdAt; // unix timestamp (seconds)
  final bool remind;

  const RemoteLoginLog({
    required this.ip,
    required this.createdAt,
    required this.remind,
  });

  factory RemoteLoginLog.fromJson(Map<String, dynamic> json) {
    return RemoteLoginLog(
      ip: json['ip']?.toString() ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      remind: (json['remind'] as int? ?? 0) == 1,
    );
  }

  String get dateDisplay {
    if (createdAt == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000).toLocal();
    final date =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

/// A notice/announcement from GET /user/notice/fetch.
class NoticeModel {
  final int id;
  final String title;
  final String content; // may contain HTML markup
  final String? imgUrl;
  final int createdAt; // unix timestamp (seconds)

  const NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    this.imgUrl,
    required this.createdAt,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json) => NoticeModel(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    imgUrl: json['img_url']?.toString(),
    createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
  );

  String get dateDisplay {
    if (createdAt == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

/// A single support ticket message from GET /user/ticket/fetch?id=N.
class TicketMessageModel {
  final int id;
  final bool isAdmin; // true = sent by support staff
  final String message;
  final int createdAt;

  const TicketMessageModel({
    required this.id,
    required this.isAdmin,
    required this.message,
    required this.createdAt,
  });

  factory TicketMessageModel.fromJson(Map<String, dynamic> json) =>
      TicketMessageModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        isAdmin: (json['is_manager'] as int? ?? 0) == 1,
        message: json['message']?.toString() ?? '',
        createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      );

  String get timeDisplay {
    if (createdAt == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000).toLocal();
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// A support ticket from GET /user/ticket/fetch.
/// level: 1=low, 2=medium, 3=high
/// status: 0=open, 1=closed
class TicketModel {
  final int id;
  final String subject;
  final int level;
  final int status;
  final int createdAt;
  final int updatedAt;
  final List<TicketMessageModel> messages;

  const TicketModel({
    required this.id,
    required this.subject,
    required this.level,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    final raw = json['message'];
    final msgs = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(TicketMessageModel.fromJson)
              .toList()
        : <TicketMessageModel>[];
    return TicketModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      subject: json['subject']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      status: (json['status'] as num?)?.toInt() ?? 0,
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      messages: msgs,
    );
  }

  bool get isOpen => status == 0;

  String get levelLabel => switch (level) {
    2 => '紧急',
    1 => '中等',
    _ => '低',
  };

  String get statusLabel => isOpen ? '处理中' : '已关闭';

  String get dateDisplay {
    final ts = updatedAt > 0 ? updatedAt : createdAt;
    if (ts == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ts * 1000).toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

/// Panel registration configuration loaded from /guest/comm/config.
class RegisterConfig {
  const RegisterConfig({
    this.emailSuffixes = const [],
    this.emailVerifyRequired = false,
    this.registerOpen = true,
  });

  /// Allowed email suffixes; empty means no restriction.
  final List<String> emailSuffixes;

  /// Whether the panel requires an emailed verification code to register.
  final bool emailVerifyRequired;

  /// Whether new-user registration is open (from the panel's comm config).
  /// Defaults to open when the panel does not report it.
  final bool registerOpen;
}

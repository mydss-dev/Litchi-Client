// Remote API response types. Separate from app_models.dart (UI view models).
// These types are panel-agnostic and do not reference any specific backend.

import '../config/app_config.dart';

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
  final double transferEnable; // bytes
  final double used; // bytes (upload + download combined)
  final int subscribeStatus; // 0=normal 1=expired 2=banned

  const RemoteUser({
    required this.id,
    required this.email,
    this.expiredAt,
    required this.balance,
    required this.transferEnable,
    required this.used,
    required this.subscribeStatus,
  });

  factory RemoteUser.fromJson(Map<String, dynamic> json) {
    final usedRaw = json['used'] ?? json['u'];
    return RemoteUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email']?.toString() ?? '',
      expiredAt: (json['expired_at'] as num?)?.toInt(),
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      transferEnable: (json['transfer_enable'] as num?)?.toDouble() ?? 0,
      used: (usedRaw as num?)?.toDouble() ?? 0,
      subscribeStatus: (json['subscribe_status'] as num?)?.toInt() ?? 0,
    );
  }

  String get expiryDisplay {
    if (expiredAt == null || expiredAt == 0) return '永久';
    final dt = DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }

  String get planLabel => subscribeStatus == 1 ? '已到期' : 'Premium';
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

  const RemoteNode({
    required this.id,
    required this.name,
    required this.rate,
    this.server = '',
    this.port = 0,
    this.rawUri = '',
  });

  factory RemoteNode.fromJson(Map<String, dynamic> json) {
    return RemoteNode(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '未知节点',
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      server: json['server']?.toString() ?? json['add']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 0,
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
  final int? onetimePrice;
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
    this.onetimePrice,
    required this.show,
  });

  factory RemotePlan.fromJson(Map<String, dynamic> json) {
    return RemotePlan(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description:
          json['content']?.toString() ?? json['description']?.toString(),
      transferEnable: (json['transfer_enable'] as num?)?.toDouble() ?? 0,
      monthPrice: (json['month_price'] as num?)?.toInt(),
      quarterPrice: (json['quarter_price'] as num?)?.toInt(),
      halfYearPrice: (json['half_year_price'] as num?)?.toInt(),
      yearPrice: (json['year_price'] as num?)?.toInt(),
      onetimePrice: (json['onetime_price'] as num?)?.toInt(),
      show: (json['show'] as num?)?.toInt() ?? 1,
    );
  }

  String get capacityDisplay {
    final gb = transferEnable / AppConfig.bytesPerGb;
    if (gb >= 1024) return '${(gb / 1024).toStringAsFixed(0)} TB';
    return '${gb.toStringAsFixed(0)} GB';
  }
}

class RemoteInvite {
  final String inviteCode;
  final String inviteUrl;
  final double commissionRate;
  final double balance; // cents
  final int effectCount;

  const RemoteInvite({
    required this.inviteCode,
    required this.inviteUrl,
    required this.commissionRate,
    required this.balance,
    required this.effectCount,
  });

  factory RemoteInvite.fromJson(Map<String, dynamic> json) {
    return RemoteInvite(
      inviteCode: json['invite_code']?.toString() ?? '',
      inviteUrl: json['invite_url']?.toString() ?? '',
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      effectCount: (json['effect_count'] as num?)?.toInt() ?? 0,
    );
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

  const SubscriptionResult({required this.nodes, this.traffic});
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
/// status: 0=pending 1=processing 2=cancelled 3=complete 4=refunded
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
    4 => '已退款',
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

  String get amountDisplay {
    final yuan = totalAmount / 100.0;
    return '¥${yuan.toStringAsFixed(2)}';
  }

  String get dateDisplay {
    if (createdAt == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}

/// Result from POST /user/order/checkout.
/// type=0: [url] is QR code content (WeChat/Alipay scheme) — show as QR.
/// type=1: [url] is a web redirect link — open in browser and optionally show QR.
/// Empty [url] means balance deduction — order processed immediately.
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
        3 => '紧急',
        2 => '中等',
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
  });

  /// Allowed email suffixes; empty means no restriction.
  final List<String> emailSuffixes;

  /// Whether the panel requires an emailed verification code to register.
  final bool emailVerifyRequired;
}

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
  final int port;      // TCP port (0 = unknown)
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
      description: json['content']?.toString() ?? json['description']?.toString(),
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
  final String date;
  final double traffic; // bytes

  const RemoteTrafficLog({required this.date, required this.traffic});

  factory RemoteTrafficLog.fromJson(Map<String, dynamic> json) {
    return RemoteTrafficLog(
      date: json['date']?.toString() ?? '',
      traffic: (json['traffic'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Traffic info parsed from subscription-userinfo response header.
class SubTraffic {
  final double upload;   // bytes
  final double download; // bytes
  final double total;    // bytes
  final int? expire;     // unix timestamp

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
        case 'upload':   upload   = double.tryParse(v) ?? 0; break;
        case 'download': download = double.tryParse(v) ?? 0; break;
        case 'total':    total    = double.tryParse(v) ?? 0; break;
        case 'expire':   expire   = int.tryParse(v); break;
      }
    }
    return SubTraffic(upload: upload, download: download, total: total, expire: expire);
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
  final int? handlingFeeFixed;   // cents
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

  const CouponResult({required this.name, required this.type, required this.value});

  factory CouponResult.fromJson(Map<String, dynamic> json) {
    return CouponResult(
      name: json['name']?.toString() ?? '',
      type: (json['type'] as num?)?.toInt() ?? 1,
      value: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

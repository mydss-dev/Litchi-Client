// Plain UI models for the mock data layer (§22). No serialization yet — these
// are immutable view models consumed directly by widgets.

class UserModel {
  const UserModel({
    required this.name,
    required this.plan,
    required this.avatarLetter,
    required this.expiry,
    this.balance = 0,
    this.remindExpire = false,
    this.remindTraffic = false,
    this.autoRenewal = false,
  });

  final String name;
  final String plan; // e.g. "Premium"
  final String avatarLetter;
  final String expiry; // e.g. "2026-07-08"
  final double balance; // cents
  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;

  UserModel copyWith({
    String? name,
    String? plan,
    String? avatarLetter,
    String? expiry,
    double? balance,
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) {
    return UserModel(
      name: name ?? this.name,
      plan: plan ?? this.plan,
      avatarLetter: avatarLetter ?? this.avatarLetter,
      expiry: expiry ?? this.expiry,
      balance: balance ?? this.balance,
      remindExpire: remindExpire ?? this.remindExpire,
      remindTraffic: remindTraffic ?? this.remindTraffic,
      autoRenewal: autoRenewal ?? this.autoRenewal,
    );
  }
}

class NodeModel {
  const NodeModel({
    required this.id,
    required this.name,
    required this.flag,
    required this.latency,
    this.code = '',
    this.englishName = '',
    this.tags = const [],
    this.favorite = false,
    this.region = NodeRegion.asia,
    this.server = '',
    this.port = 0,
    this.isAuto = false,
    this.rawUri = '',
  });

  final String id;
  final String name;
  final String flag;

  /// ISO 3166-1 alpha-2 code, e.g. "HK", "SG".
  final String code;

  /// English region name, e.g. "Hong Kong", "Singapore".
  final String englishName;

  /// -1 = testing in progress, 0 = not tested, >0 = real ms, 9999 = timeout
  final int latency;
  final List<String> tags;
  final bool favorite;
  final NodeRegion region;
  final String server;
  final int port;

  /// True for the virtual "自动选择" entry.
  final bool isAuto;

  /// Original proxy URI for sing-box config generation.
  final String rawUri;

  NodeModel copyWith({int? latency}) => NodeModel(
    id: id,
    name: name,
    flag: flag,
    code: code,
    englishName: englishName,
    latency: latency ?? this.latency,
    tags: tags,
    favorite: favorite,
    region: region,
    server: server,
    port: port,
    isAuto: isAuto,
    rawUri: rawUri,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'flag': flag,
    'code': code,
    'englishName': englishName,
    'tags': tags,
    'favorite': favorite,
    'region': region.name,
    'server': server,
    'port': port,
    'isAuto': isAuto,
    'rawUri': rawUri,
  };

  factory NodeModel.fromJson(Map<String, dynamic> j) => NodeModel(
    id: j['id'] as String,
    name: j['name'] as String,
    flag: j['flag'] as String,
    code: j['code'] as String? ?? '',
    englishName: j['englishName'] as String? ?? '',
    tags: (j['tags'] as List?)?.cast<String>() ?? [],
    favorite: j['favorite'] as bool? ?? false,
    region: NodeRegion.values.firstWhere(
      (r) => r.name == j['region'],
      orElse: () => NodeRegion.asia,
    ),
    server: j['server'] as String? ?? '',
    port: j['port'] as int? ?? 0,
    isAuto: j['isAuto'] as bool? ?? false,
    rawUri: j['rawUri'] as String? ?? '',
    latency: 0,
  );
}

enum NodeRegion { asia, europe, america, oceania }

class InviteCodeModel {
  const InviteCodeModel({required this.code, required this.link});

  final String code;
  final String link;
}

class TrafficModel {
  const TrafficModel({
    required this.totalGb,
    required this.usedGb,
    required this.remainGb,
  });

  final double totalGb;
  final double usedGb;
  final double remainGb;

  double get usedPercent => totalGb == 0 ? 0 : usedGb / totalGb * 100;
}

class TrafficUsagePoint {
  const TrafficUsagePoint({
    required this.date,
    required this.totalGb,
    this.uploadGb = 0,
    this.downloadGb = 0,
  });

  final DateTime date;
  final double totalGb;
  final double uploadGb;
  final double downloadGb;
}

class DeviceModel {
  const DeviceModel({
    required this.name,
    required this.platform,
    required this.lastActive,
    this.online = true,
  });

  final String name;
  final String platform; // "Windows 11", "iOS 17", "macOS 14"
  final String lastActive;
  final bool online;
}

/// Shop product categories (§12, finalized with the user).
enum PlanCategory { recurring, oneTime, dataPack }

/// Billing cycle, only meaningful for [PlanCategory.recurring].
enum BillingCycle { monthly, quarterly, halfYear, yearly }

/// Proxy routing mode. Replaces the old Chinese magic-string constants.
enum ProxyMode {
  rule,
  global,
  direct;

  /// Display label shown in UI.
  String get label => switch (this) {
    ProxyMode.rule => '规则模式',
    ProxyMode.global => '全局模式',
    ProxyMode.direct => '直连模式',
  };

  /// Value sent to the Clash-compatible API (sing-box `/configs` endpoint).
  String get clashValue => switch (this) {
    ProxyMode.rule => 'rule',
    ProxyMode.global => 'global',
    ProxyMode.direct => 'direct',
  };

  /// Stable key used when persisting to SharedPreferences.
  String get storageKey => clashValue;

  /// Deserialises from storage key or the old Chinese label strings.
  static ProxyMode fromStorageKey(String? key) => switch (key) {
    'global' || '全局模式' => ProxyMode.global,
    'direct' || '直连模式' => ProxyMode.direct,
    _ => ProxyMode.rule,
  };
}

/// Network interception mode — controls how sing-box captures traffic.
enum NetworkMode {
  system,
  tun;

  String get label => switch (this) {
    NetworkMode.system => '系统代理',
    NetworkMode.tun => '虚拟网卡',
  };

  String get storageKey => switch (this) {
    NetworkMode.system => 'system',
    NetworkMode.tun => 'tun',
  };

  static NetworkMode fromStorageKey(String? key) => switch (key) {
    'tun' => NetworkMode.tun,
    _ => NetworkMode.system,
  };
}

class PlanModel {
  const PlanModel({
    required this.id,
    required this.title,
    required this.capacity,
    required this.category,
    this.monthlyPrice,
    this.quarterlyPrice,
    this.halfYearPrice,
    this.yearlyPrice,
    this.oneTimePrice,
    this.deviceLimit,
    this.features = const [],
    this.hot = false,
    this.featured = false,
  });

  final String id;
  final String title;
  final String capacity; // e.g. "128G"
  final PlanCategory category;

  // Recurring prices per cycle.
  final double? monthlyPrice;
  final double? quarterlyPrice;
  final double? halfYearPrice;
  final double? yearlyPrice;

  // One-time / data-pack price.
  final double? oneTimePrice;

  final int? deviceLimit;
  final List<String> features;
  final bool hot;
  final bool featured;

  double? priceForCycle(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.monthly:
        return monthlyPrice;
      case BillingCycle.quarterly:
        return quarterlyPrice;
      case BillingCycle.halfYear:
        return halfYearPrice;
      case BillingCycle.yearly:
        return yearlyPrice;
    }
  }
}

class LoginRecord {
  const LoginRecord({
    required this.location,
    required this.device,
    required this.time,
    this.suspicious = false,
  });

  final String location;
  final String device;
  final String time;
  final bool suspicious;
}

/// Carries version info returned by the update manifest endpoint.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    this.changelog = '',
  });

  final String version;
  final String downloadUrl;
  final String changelog;
}

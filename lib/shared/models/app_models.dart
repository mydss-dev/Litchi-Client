// Plain UI models for the mock data layer (§22). No serialization yet — these
// are immutable view models consumed directly by widgets.

class UserModel {
  const UserModel({
    required this.name,
    required this.plan,
    required this.avatarLetter,
    required this.expiry,
  });

  final String name;
  final String plan; // e.g. "Premium"
  final String avatarLetter;
  final String expiry; // e.g. "2026-07-08"
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
}

enum NodeRegion { asia, europe, america, oceania }

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
enum BillingCycle { monthly, quarterly, yearly }

class PlanModel {
  const PlanModel({
    required this.id,
    required this.title,
    required this.capacity,
    required this.category,
    this.monthlyPrice,
    this.quarterlyPrice,
    this.yearlyPrice,
    this.oneTimePrice,
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
  final double? yearlyPrice;

  // One-time / data-pack price.
  final double? oneTimePrice;

  final List<String> features;
  final bool hot;
  final bool featured;

  double? priceForCycle(BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.monthly:
        return monthlyPrice;
      case BillingCycle.quarterly:
        return quarterlyPrice;
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

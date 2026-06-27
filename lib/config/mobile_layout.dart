// Mobile UI layout defaults.
//
// These are local-only (not in OSS remote config). Edit this file directly and
// rebuild — no re-signing needed.

// ── Config types ─────────────────────────────────────────────────────────────

class MobileHomeCardConfig {
  const MobileHomeCardConfig({
    required this.type,
    required this.title,
    required this.icon,
    this.visible = true,
  });

  final String type;
  final String title;
  final String icon;
  final bool visible;

  factory MobileHomeCardConfig.fromJson(Map<String, dynamic> json) {
    String read(String key) =>
        json[key] is String ? (json[key] as String).trim() : '';
    return MobileHomeCardConfig(
      type: read('type'),
      title: read('title'),
      icon: read('icon'),
      visible: json['visible'] is bool ? json['visible'] as bool : true,
    );
  }
}

class MobileTabConfig {
  const MobileTabConfig({
    required this.type,
    required this.label,
    required this.icon,
  });

  final String type;
  final String label;
  final String icon;

  factory MobileTabConfig.fromJson(dynamic raw) {
    if (raw is String) {
      return MobileTabConfig(type: raw.trim(), label: '', icon: '');
    }
    if (raw is Map) {
      final json = Map<String, dynamic>.from(raw);
      String read(String key) =>
          json[key] is String ? (json[key] as String).trim() : '';
      return MobileTabConfig(
        type: read('type'),
        label: read('label').isNotEmpty ? read('label') : read('title'),
        icon: read('icon'),
      );
    }
    return const MobileTabConfig(type: '', label: '', icon: '');
  }
}

class MobileProfileMenuConfig {
  const MobileProfileMenuConfig({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.visible = true,
  });

  final String type;
  final String title;
  final String subtitle;
  final String icon;
  final bool visible;

  factory MobileProfileMenuConfig.fromJson(Map<String, dynamic> json) {
    String read(String key) =>
        json[key] is String ? (json[key] as String).trim() : '';
    return MobileProfileMenuConfig(
      type: read('type'),
      title: read('title').isNotEmpty ? read('title') : read('label'),
      subtitle: read('subtitle'),
      icon: read('icon'),
      visible: json['visible'] is bool ? json['visible'] as bool : true,
    );
  }
}

// ── Defaults ─────────────────────────────────────────────────────────────────

abstract final class MobileLayout {
  // ── Home cards (top of mobile home page, max 4) ───────────────────────────

  /// Supported types: currentPlan, remainTraffic, todayTraffic, downSpeed,
  /// upSpeed, resetDay, deviceLimit, expireDate.
  static const List<MobileHomeCardConfig> homeCards = [
    MobileHomeCardConfig(type: 'downSpeed', title: '下行速率', icon: 'download'),
    MobileHomeCardConfig(type: 'upSpeed', title: '上行速率', icon: 'upload'),
  ];

  // ── Bottom tab bar (max 3) ────────────────────────────────────────────────

  /// Supported types: shop, invite, tickets, wallet, orders, traffic.
  static const List<MobileTabConfig> tabs = [
    MobileTabConfig(type: 'shop', label: '套餐', icon: 'shoppingBag'),
    MobileTabConfig(type: 'invite', label: '邀请', icon: 'gift'),
  ];

  // ── Profile page ──────────────────────────────────────────────────────────

  /// Summary card type: traffic | expire | expireDate | plan | currentPlan.
  static const String profileSummaryCard = 'traffic';

  /// Menu layout: list | grid.
  static const String profileMenuLayout = 'grid';

  /// Supported types: wallet, orders, tickets, traffic, invite, shop.
  static const List<MobileProfileMenuConfig> profileMenu = [
    MobileProfileMenuConfig(
      type: 'wallet',
      title: '我的钱包',
      subtitle: '余额、佣金与账户充值',
      icon: 'wallet',
    ),
    MobileProfileMenuConfig(
      type: 'orders',
      title: '订单记录',
      subtitle: '查看购买记录与支付状态',
      icon: 'clipboardList',
    ),
    MobileProfileMenuConfig(
      type: 'tickets',
      title: '工单支持',
      subtitle: '联系在线客服',
      icon: 'messageSquare',
    ),
  ];
}

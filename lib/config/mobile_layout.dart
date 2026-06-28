// Compact-layout UI configuration.
//
// Navigation is now driven by the single-source-of-truth `kNavDestinations`
// in `lib/app/nav_destinations.dart`.  This file only holds the dashboard
// home-card display config.

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

// ── Defaults ─────────────────────────────────────────────────────────────────

abstract final class MobileLayout {
  // ── Home cards (top of compact home page, max 4) ───────────────────────────

  /// Supported types: currentPlan, remainTraffic, todayTraffic, downSpeed,
  /// upSpeed, resetDay, deviceLimit, expireDate.
  static const List<MobileHomeCardConfig> homeCards = [
    MobileHomeCardConfig(type: 'downSpeed', title: '下行速率', icon: 'download'),
    MobileHomeCardConfig(type: 'upSpeed', title: '上行速率', icon: 'upload'),
  ];
}

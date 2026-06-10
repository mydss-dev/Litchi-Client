import 'app_models.dart';

/// Static mock data backing the UI (§22). No backend (§3 rule 3).
class MockData {
  MockData._();

  static const UserModel user = UserModel(
    name: 'Bruce',
    plan: 'Premium',
    avatarLetter: 'B',
    expiry: '2026-07-08',
  );

  static const TrafficModel traffic = TrafficModel(
    totalGb: 850,
    usedGb: 430,
    remainGb: 420,
  );

  static const NodeModel currentNode = NodeModel(
    id: 'sg-01',
    name: '新加坡 01',
    flag: '🇸🇬',
    latency: 31,
    tags: ['Premium'],
    region: NodeRegion.asia,
  );

  static const List<NodeModel> nodes = [
    NodeModel(id: 'sg-01', name: '新加坡 01', flag: '🇸🇬', latency: 31, tags: ['Premium'], favorite: true, region: NodeRegion.asia),
    NodeModel(id: 'jp-01', name: '日本 01', flag: '🇯🇵', latency: 48, tags: ['Premium'], region: NodeRegion.asia),
    NodeModel(id: 'hk-01', name: '香港 01', flag: '🇭🇰', latency: 33, tags: ['Premium'], region: NodeRegion.asia),
    NodeModel(id: 'us-01', name: '美国 01', flag: '🇺🇸', latency: 120, tags: ['Premium'], region: NodeRegion.america),
    NodeModel(id: 'tw-01', name: '台湾 01', flag: '🇹🇼', latency: 36, tags: ['Premium'], region: NodeRegion.asia),
    NodeModel(id: 'kr-01', name: '韩国 01', flag: '🇰🇷', latency: 55, tags: ['Premium'], region: NodeRegion.asia),
  ];

  static const List<DeviceModel> devices = [
    DeviceModel(name: 'DESKTOP-7H9K2L', platform: 'Windows 11', lastActive: '刚刚'),
    DeviceModel(name: 'iPhone 16', platform: 'iOS 18', lastActive: '2 小时前'),
    DeviceModel(name: 'MacBook Air', platform: 'macOS 15', lastActive: '昨天', online: false),
  ];

  /// Daily traffic usage (GB) for the statistics bar chart.
  static const List<double> dailyUsage = [
    12, 18, 9, 22, 27, 15, 19, 24, 11, 30,
    21, 16, 26, 14, 20, 28, 13, 23, 17, 25,
    19, 22, 31, 18, 27, 15, 21, 29, 16, 24,
  ];

  static const List<LoginRecord> loginRecords = [
    LoginRecord(location: '新加坡', device: 'Windows 客户端', time: '2026-06-09 09:12'),
    LoginRecord(location: '香港', device: 'iOS 客户端', time: '2026-06-08 21:40'),
    LoginRecord(location: '未知位置', device: 'Web', time: '2026-06-07 03:18', suspicious: true),
  ];

  static const String inviteCode = 'BRUCE888';
  static const String inviteLink = 'https://litchi.com/register?code=BRUCE888';
  static const int invitedCount = 12;
  static const double commissionRate = 20;
  static const double withdrawable = 256.00;

  // ---- Shop plans (§12) -----------------------------------------------------
  static const List<PlanModel> plans = [
    PlanModel(
      id: 'plan-128',
      title: '直连小杯套餐',
      capacity: '128G',
      category: PlanCategory.recurring,
      monthlyPrice: 20,
      quarterlyPrice: 54,
      yearlyPrice: 192,
      hot: true,
      features: ['128GB 月流量', '解锁全部节点', '最高 3 台设备', '7×24 小时客服'],
    ),
    PlanModel(
      id: 'plan-256',
      title: '直连中杯套餐',
      capacity: '256G',
      category: PlanCategory.recurring,
      monthlyPrice: 35,
      quarterlyPrice: 95,
      yearlyPrice: 336,
      features: ['256GB 月流量', '解锁全部节点', '最高 5 台设备', '7×24 小时客服'],
    ),
    PlanModel(
      id: 'plan-1tb',
      title: '旗舰套餐',
      capacity: '1TB',
      category: PlanCategory.recurring,
      monthlyPrice: 88,
      quarterlyPrice: 238,
      yearlyPrice: 845,
      featured: true,
      features: ['1TB 月流量', '解锁全部节点', '不限设备数量', '专属优先线路'],
    ),
    PlanModel(
      id: 'pack-500',
      title: '不限时套餐',
      capacity: '500G',
      category: PlanCategory.oneTime,
      oneTimePrice: 58,
      hot: true,
      features: ['500GB 总流量', '不限使用时间', '流量用完即止', '解锁全部节点'],
    ),
    PlanModel(
      id: 'addon-100',
      title: '流量加量包',
      capacity: '+100G',
      category: PlanCategory.dataPack,
      oneTimePrice: 18,
      features: ['叠加到当前套餐', '+100GB 流量', '即时生效', '不改变到期时间'],
    ),
    PlanModel(
      id: 'addon-300',
      title: '流量加量包',
      capacity: '+300G',
      category: PlanCategory.dataPack,
      oneTimePrice: 45,
      features: ['叠加到当前套餐', '+300GB 流量', '即时生效', '不改变到期时间'],
    ),
  ];
}

import 'package:flutter/material.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';

class VisualV3Controller extends AppController {
  VisualV3Controller(this.visualPage);

  final AppPage visualPage;
  final _VisualPanelApi _visualApi = _VisualPanelApi();
  final ValueNotifier<int> _up = ValueNotifier<int>(3 * 1024 * 1024);
  final ValueNotifier<int> _down = ValueNotifier<int>(12 * 1024 * 1024);

  static const _node = NodeModel(
    id: 'jp-01',
    name: '日本 东京 · Premium',
    flag: '🇯🇵',
    code: 'JP',
    englishName: 'Tokyo Premium',
    latency: 42,
    favorite: true,
    region: NodeRegion.asia,
  );

  static const _nodes = <NodeModel>[
    _node,
    NodeModel(
      id: 'hk-01',
      name: '香港 · Premium',
      flag: '🇭🇰',
      code: 'HK',
      englishName: 'Hong Kong',
      latency: 31,
      region: NodeRegion.asia,
    ),
    NodeModel(
      id: 'sg-01',
      name: '新加坡 · Standard',
      flag: '🇸🇬',
      code: 'SG',
      englishName: 'Singapore',
      latency: 66,
      region: NodeRegion.asia,
    ),
    NodeModel(
      id: 'us-01',
      name: '美国 洛杉矶',
      flag: '🇺🇸',
      code: 'US',
      englishName: 'Los Angeles',
      latency: 128,
      region: NodeRegion.america,
    ),
  ];

  static const _user = UserModel(
    name: 'Litchi User',
    plan: 'Litchi Ultra · 512G',
    avatarLetter: 'L',
    expiry: '2026-12-31',
    balance: 12880,
    remindExpire: true,
    remindTraffic: true,
  );

  static const _remoteUser = RemoteUser(
    id: 7,
    email: 'litchi-user@example.com',
    expiredAt: 1798675200,
    balance: 12880,
    transferEnable: 512,
    used: 128,
    subscribeStatus: 0,
    planId: 8,
    planName: 'Litchi Ultra · 512G',
    remindExpire: true,
    remindTraffic: true,
    autoRenewal: false,
  );

  static const _traffic = TrafficModel(
    totalGb: 512,
    usedGb: 128.4,
    remainGb: 383.6,
  );

  static const _plans = <PlanModel>[
    PlanModel(
      id: '8',
      title: 'Litchi Ultra · 512G',
      capacity: '512G',
      category: PlanCategory.recurring,
      monthlyPrice: 12.8,
      quarterlyPrice: 34.8,
      yearlyPrice: 118,
      deviceLimit: 5,
      features: ['高速线路', '多设备', '全球节点'],
      hot: true,
      featured: true,
    ),
    PlanModel(
      id: '9',
      title: 'Litchi Prime · 1024G',
      capacity: '1024G',
      category: PlanCategory.recurring,
      monthlyPrice: 22.8,
      quarterlyPrice: 62.8,
      yearlyPrice: 218,
      deviceLimit: 8,
      features: ['旗舰线路', '高流量', '优先节点'],
      featured: true,
    ),
    PlanModel(
      id: '10',
      title: '300G 流量包',
      capacity: '300G',
      category: PlanCategory.dataPack,
      oneTimePrice: 18,
      features: ['一次性流量', '叠加使用'],
    ),
  ];

  static const _notices = <NoticeModel>[
    NoticeModel(
      id: 1,
      title: '服务公告',
      content: '香港、日本线路已完成优化，连接异常时可切换节点后重试。',
      createdAt: 1789430400,
    ),
  ];

  static const _inviteCodes = <InviteCodeModel>[
    InviteCodeModel(
      code: 'LITCHI88',
      link: 'https://thelitchi.com/#/register?code=LITCHI88',
    ),
  ];

  static const _inviteRecords = <RemoteInviteRecord>[
    RemoteInviteRecord(
      id: 1,
      tradeNo: 'INV-001',
      userName: 'friend@example.com',
      orderAmount: 1280,
      commissionAmount: 256,
      createdAt: 1789430400,
    ),
  ];

  @override
  AppPage get page => visualPage;
  @override
  bool get isAuthenticated => true;
  @override
  bool get isInitializing => false;
  @override
  PanelApi get api => _visualApi;
  @override
  UserModel get user => _user;
  @override
  RemoteUser? get accountDetails => _remoteUser;
  // The real method fans out to every panel service; in a widget test that
  // would be a network call. Nothing the visual fixtures render depends on the
  // refreshed data, so the flows that await it (gift-card redeem, Telegram
  // bind/unbind) complete deterministically instead.
  @override
  Future<void> refreshData() async {}
  @override
  TrafficModel get traffic => _traffic;
  @override
  NodeModel get currentNode => _node;
  @override
  List<NodeModel> get nodes => _nodes;
  @override
  bool get autoSelected => false;
  @override
  List<PlanModel> get plans => _plans;
  @override
  int? get currentPlanId => 8;
  @override
  bool get hasPlan => true;
  @override
  String get currencySymbol => '¥';
  @override
  ConnectionStatus get connectionStatus => ConnectionStatus.connected;
  @override
  bool get coreRunning => true;
  @override
  bool get coreConnecting => false;
  @override
  bool get connectionActionLocked => false;
  @override
  bool get supportsCoreConnection => true;
  @override
  Duration get connectedDuration =>
      const Duration(hours: 1, minutes: 26, seconds: 18);
  @override
  ValueNotifier<int> get upBpsNotifier => _up;
  @override
  ValueNotifier<int> get downBpsNotifier => _down;
  @override
  int get upBps => _up.value;
  @override
  int get downBps => _down.value;
  @override
  NetworkMode get networkMode => NetworkMode.tun;
  @override
  ProxyMode get proxyMode => ProxyMode.rule;
  @override
  DnsMode get dnsMode => DnsMode.cloudflare;
  @override
  int get proxyPort => 7890;
  @override
  int get activeProxyPort => 7890;
  @override
  bool get killSwitch => true;
  @override
  bool get autoStart => true;
  @override
  bool get silentStart => false;
  @override
  bool get autoUpdate => true;
  @override
  ThemeMode get themeMode => ThemeMode.light;
  @override
  List<NoticeModel> get notices => _notices;
  @override
  bool get noticesLoading => false;
  @override
  List<NoticeModel> get pendingNoticePopups => const [];
  // No update by default, so no golden depends on the host platform: the
  // banner's action differs between desktop and the rest.
  @override
  UpdateInfo? get updateInfo => null;
  @override
  void dismissUpdate() {}
  @override
  bool get hasAccountSummary => true;
  @override
  bool get isInitialLoading => false;
  @override
  double get todayTrafficGb => 2.48;
  @override
  int? get aliveIp => 2;
  @override
  int? get deviceLimit => 5;
  @override
  int? get resetDay => 1;
  @override
  int? get expiredAt => 1798675200;
  @override
  List<double> get dailyUsage => const [1.8, 2.4, 3.1, 2.2, 4.8, 3.6, 2.48];
  @override
  List<TrafficUsagePoint> get trafficUsage => [
    TrafficUsagePoint(
      date: DateTime(2026, 9, 11),
      totalGb: 2.4,
      uploadGb: 0.4,
      downloadGb: 2.0,
    ),
    TrafficUsagePoint(
      date: DateTime(2026, 9, 12),
      totalGb: 3.1,
      uploadGb: 0.5,
      downloadGb: 2.6,
    ),
    TrafficUsagePoint(
      date: DateTime(2026, 9, 13),
      totalGb: 2.2,
      uploadGb: 0.4,
      downloadGb: 1.8,
    ),
    TrafficUsagePoint(
      date: DateTime(2026, 9, 14),
      totalGb: 4.8,
      uploadGb: 0.8,
      downloadGb: 4.0,
    ),
    TrafficUsagePoint(
      date: DateTime(2026, 9, 15),
      totalGb: 3.6,
      uploadGb: 0.6,
      downloadGb: 3.0,
    ),
  ];
  @override
  List<InviteCodeModel> get inviteCodes => _inviteCodes;
  @override
  String get inviteCode => 'LITCHI88';
  @override
  String get inviteLink => 'https://thelitchi.com/#/register?code=LITCHI88';
  @override
  List<RemoteInviteRecord> get inviteRecords => _inviteRecords;
  @override
  double get commissionRate => 20;
  @override
  int get invitedCount => 12;
  @override
  double get earnedCommission => 88.6;
  @override
  double get pendingCommission => 16.8;
  @override
  double get withdrawable => 71.8;
  @override
  bool get withdrawEnabled => true;
  @override
  List<String> get withdrawMethods => const ['支付宝', 'USDT'];
  @override
  double get minWithdrawAmount => 20;

  void disposeVisual() {
    _up.dispose();
    _down.dispose();
    dispose();
  }
}

class _VisualPanelApi extends PanelApi {
  _VisualPanelApi() : super(ApiClient());

  static const _orders = <RemoteOrder>[
    RemoteOrder(
      tradeNo: 'L202609160001',
      planName: 'Litchi Ultra · 512G',
      period: 'month_price',
      totalAmount: 1280,
      status: 0,
      createdAt: 1789516800,
    ),
    RemoteOrder(
      tradeNo: 'L202609120018',
      planName: 'Litchi Prime · 1024G',
      period: 'quarter_price',
      totalAmount: 6280,
      status: 3,
      createdAt: 1789171200,
    ),
  ];

  static const _tickets = <TicketModel>[
    TicketModel(
      id: 101,
      subject: '香港节点连接问题',
      level: 2,
      status: 0,
      createdAt: 1789430400,
      updatedAt: 1789516800,
      messages: [
        TicketMessageModel(
          id: 1,
          isAdmin: false,
          message: '连接香港节点后偶尔无法访问，请帮忙检查。',
          createdAt: 1789430400,
        ),
        TicketMessageModel(
          id: 2,
          isAdmin: true,
          message: '已为线路执行切换，请重新连接后测试。',
          createdAt: 1789516800,
        ),
      ],
    ),
    TicketModel(
      id: 99,
      subject: '套餐到账确认',
      level: 1,
      status: 1,
      createdAt: 1789000000,
      updatedAt: 1789086400,
    ),
  ];

  @override
  Future<List<RemoteOrder>> fetchOrders() async => _orders;
  @override
  Future<List<TicketModel>> getTickets() async => _tickets;
  @override
  Future<TicketModel> getTicketDetail(int ticketId) async =>
      _tickets.firstWhere((ticket) => ticket.id == ticketId);

  // Telegram binding runs entirely through these three, none of which touch
  // the network in a widget test.
  @override
  Future<String> getTelegramBotUsername() async => 'litchi_bot';
  @override
  Future<String> getSubscribeUrl() async => 'https://thelitchi.com/sub/litchi';
  @override
  Future<void> unbindTelegram() async {}
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/features/dashboard/dashboard_page.dart';
import 'package:litchi_client/l10n/generated/app_localizations.dart';
import 'package:litchi_client/shared/layout/app_platform.dart';
import 'package:litchi_client/shared/layout/app_shell_spec.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/theme/app_theme.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment(
  'LITCHI_VISUAL_SNAPSHOTS',
);

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    required ThemeMode themeMode,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = _AndroidVisualDashboardController();
    addTearDown(controller.disposeVisualState);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppScope(
          controller: controller,
          child: Scaffold(
            body: Padding(
              padding: AppShellSpec.pagePaddingFor(AppPlatform.current),
              child: const DashboardPage(),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
  }

  testWidgets(
    'Android 390x844 dashboard light visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpDashboard(
          tester,
          themeMode: ThemeMode.light,
          size: const Size(390, 844),
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/android_dashboard_light_390x844.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Android 390x844 dashboard dark visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpDashboard(
          tester,
          themeMode: ThemeMode.dark,
          size: const Size(390, 844),
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/android_dashboard_dark_390x844.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Android 360x800 dashboard light narrow visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpDashboard(
          tester,
          themeMode: ThemeMode.light,
          size: const Size(360, 800),
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/android_dashboard_light_360x800.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );

  testWidgets(
    'Android 360x800 dashboard dark narrow visual',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await pumpDashboard(
          tester,
          themeMode: ThemeMode.dark,
          size: const Size(360, 800),
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/android_dashboard_dark_360x800.png'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
    skip: !_visualSnapshotsEnabled,
  );
}

class _AndroidVisualDashboardController extends AppController {
  final ValueNotifier<int> _up = ValueNotifier<int>(3 * 1024 * 1024);
  final ValueNotifier<int> _down = ValueNotifier<int>(12 * 1024 * 1024);

  static const _node = NodeModel(
    id: 'visual-tokyo-01',
    name: '日本 东京 · Premium',
    flag: '🇯🇵',
    code: 'JP',
    englishName: 'Tokyo Premium',
    latency: 42,
    favorite: true,
    region: NodeRegion.asia,
  );

  static const _user = UserModel(
    name: 'Litchi User',
    plan: 'Litchi Ultra · 512G',
    avatarLetter: 'L',
    expiry: '2026-12-31',
  );

  static const _traffic = TrafficModel(
    totalGb: 512,
    usedGb: 128.4,
    remainGb: 383.6,
  );

  static const _notices = <NoticeModel>[
    NoticeModel(
      id: 1,
      title: '服务公告',
      content: '香港、日本线路已完成优化，连接异常时可切换节点后重试。',
      createdAt: 1789430400,
    ),
  ];

  @override
  AppPage get page => AppPage.dashboard;

  @override
  bool get coreRunning => false;

  @override
  ConnectionStatus get connectionStatus => ConnectionStatus.connected;

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
  NetworkMode get networkMode => NetworkMode.system;

  @override
  ProxyMode get proxyMode => ProxyMode.rule;

  @override
  NodeModel get currentNode => _node;

  @override
  List<NodeModel> get nodes => const [_node];

  @override
  bool get autoSelected => false;

  @override
  UserModel get user => _user;

  @override
  TrafficModel get traffic => _traffic;

  @override
  double get todayTrafficGb => 2.48;

  @override
  int? get expiredAt =>
      DateTime(2026, 12, 31).millisecondsSinceEpoch ~/ 1000;

  @override
  bool get hasAccountSummary => true;

  @override
  bool get isInitialLoading => false;

  @override
  bool get hasPlan => true;

  @override
  List<NoticeModel> get notices => _notices;

  @override
  bool get noticesLoading => false;

  @override
  List<NoticeModel> get pendingNoticePopups => const [];

  void disposeVisualState() {
    _up.dispose();
    _down.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_notice_bar.dart';

import 'v3_visual_fixture.dart';

/// Notices and update prompts must consume existing controller state.
class _NewsController extends VisualV3Controller {
  _NewsController({List<NoticeModel> notices = const [], this.update})
    : _live = notices,
      super(AppPage.dashboard);

  final List<NoticeModel> _live;

  /// Mutable so a dismissal can actually take the banner away.
  UpdateInfo? update;
  final List<int> seen = [];
  int dismissals = 0;

  @override
  List<NoticeModel> get notices => _live;

  @override
  List<NoticeModel> get pendingNoticePopups =>
      _live.where((n) => n.isPopup && !seen.contains(n.id)).toList();

  @override
  void markNoticePopupSeen(int id) {
    seen.add(id);
    notifyListeners();
  }

  @override
  UpdateInfo? get updateInfo => update;

  @override
  void dismissUpdate() {
    dismissals++;
    update = null;
    notifyListeners();
  }
}

const _notice = NoticeModel(
  id: 4,
  title: '服务公告',
  content: '<p>香港、日本线路<b>已完成优化</b>。</p>',
  createdAt: 1789430400,
);

const _older = NoticeModel(
  id: 3,
  title: '维护通知',
  content: '凌晨例行维护。',
  createdAt: 1789344000,
);

const _popup = NoticeModel(
  id: 9,
  title: '隐私政策更新',
  content: '请阅读并同意新的隐私政策。',
  tags: ['弹窗'],
  createdAt: 1789516800,
);

const _popup2 = NoticeModel(
  id: 10,
  title: '服务条款更新',
  content: '请阅读并同意新的服务条款。',
  tags: ['弹窗'],
  createdAt: 1789603200,
);

const _update = UpdateInfo(
  version: '9.9.9',
  downloadUrl: 'https://example.com/litchi-9.9.9.exe',
  changelog: '修复了若干问题',
);

const _phone = Size(390, 844);

/// Advances far enough for a route to be pushed and to finish animating in.
/// `pumpAndSettle` is not usable with a repeating two-notice ticker.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpPage(
  WidgetTester tester,
  _NewsController controller,
  Widget page,
) async {
  // Desktop lane: the one-line ticker. Phones render the image carousel
  // instead, which has its own contract.
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(body: page),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the dashboard shows only a notice title, not inline body', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _NewsController(notices: const [_notice]),
      const V3DashboardPage(),
    );

    expect(find.byType(V3NoticeBar), findsOneWidget);
    expect(find.text('服务公告'), findsOneWidget);
    expect(find.textContaining('香港、日本线路'), findsNothing);
    expect(find.textContaining('<b>'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('the notice bar renders nothing when there is no news', (
    tester,
  ) async {
    await _pumpPage(tester, _NewsController(), const V3DashboardPage());

    expect(find.byType(V3NoticeBar), findsOneWidget);
    expect(find.text('查看'), findsNothing);
    expect(find.byIcon(Icons.campaign_rounded), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ticker advances through the notices it was given', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _NewsController(notices: const [_notice, _older]),
      const V3DashboardPage(),
    );

    expect(find.textContaining('服务公告'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    expect(find.textContaining('维护通知'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('查看 opens the notice with its body unescaped', (tester) async {
    await _pumpPage(
      tester,
      _NewsController(notices: const [_notice]),
      const V3DashboardPage(),
    );

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();

    expect(find.byType(V3NoticeDialog), findsOneWidget);
    expect(find.text('香港、日本线路已完成优化。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(V3NoticeDialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dashboard offers a concise update and drops it when dismissed', (
    tester,
  ) async {
    final controller = _NewsController(update: _update);
    await _pumpPage(tester, controller, const V3DashboardPage());

    expect(find.byType(V3NoticeBar), findsOneWidget);
    expect(find.text('发现新版本 9.9.9'), findsOneWidget);
    expect(find.text('修复了若干问题'), findsNothing,
      reason: 'raw changelog belongs outside the concise update banner');

    // Desktop installation and download-page actions differ by platform.
    await tester.tap(find.byTooltip('暂不提示'));
    await tester.pumpAndSettle();

    expect(controller.dismissals, 1);
    expect(find.text('发现新版本 9.9.9'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('a must-read notice pops once, then is recorded as seen', (
    tester,
  ) async {
    final controller = _NewsController(notices: const [_popup]);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(), home: const V3Shell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(V3NoticeDialog), findsOneWidget);
    expect(find.descendant(of: find.byType(V3NoticeDialog),
      matching: find.text('隐私政策更新')), findsOneWidget);

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    expect(find.byType(V3NoticeDialog), findsNothing);
    expect(controller.seen, [9], reason: 'the popup must be marked seen');
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending must-read notices are shown one at a time', (
    tester,
  ) async {
    final controller = _NewsController(notices: const [_popup, _popup2]);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(), home: const V3Shell()),
      ),
    );
    await _frames(tester);

    expect(find.descendant(of: find.byType(V3NoticeDialog),
      matching: find.text('隐私政策更新')), findsOneWidget);
    expect(find.descendant(of: find.byType(V3NoticeDialog),
      matching: find.text('服务条款更新')), findsNothing);

    await tester.tap(find.text('我知道了'));
    await _frames(tester);
    expect(controller.seen, [9]);
    expect(find.descendant(of: find.byType(V3NoticeDialog),
      matching: find.text('服务条款更新')), findsOneWidget);

    await tester.tap(find.text('我知道了'));
    await _frames(tester);
    expect(controller.seen, [9, 10]);
    expect(find.byType(V3NoticeDialog), findsNothing);

    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('a must-read notice already seen is not shown', (tester) async {
    final controller = _NewsController(notices: const [_popup])..seen.add(9);
    await tester.binding.setSurfaceSize(_phone);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(theme: V3Theme.light(), home: const V3Shell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(V3NoticeHost), findsOneWidget);
    expect(find.byType(V3NoticeDialog), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets('notices and the update share one rotating lane', (tester) async {
    final controller = _NewsController(notices: const [_notice], update: _update);
    await _pumpPage(tester, controller, const V3DashboardPage());

    // One lane, not two stacked banners. The rotation starts on notices.
    expect(find.byType(V3NoticeBar), findsOneWidget);
    expect(find.textContaining('服务公告'), findsOneWidget);
    expect(find.text('发现新版本 9.9.9'), findsNothing,
      reason: 'the update is a page of the same lane, not a second banner');
    final laneHeight = tester.getRect(find.byType(V3NoticeBar)).height;
    expect(laneHeight, lessThan(80),
      reason: 'the top lane must stay within the first-screen budget');
    // The first screen still reaches the connect orb with the lane present.
    expect(tester.getRect(find.byKey(kConnectOrbKey)).bottom, lessThan(700));

    // The rotation reaches the update page.
    await tester.pump(const Duration(seconds: 9));
    expect(find.textContaining('发现新版本 9.9.9'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox());
  });
}

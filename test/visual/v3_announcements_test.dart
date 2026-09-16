import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_notice_bar.dart';
import 'package:litchi_client/v3/ui/v3_update_banner.dart';

import 'v3_visual_fixture.dart';

/// The two "news" surfaces the rebuild dropped: notices and the update prompt.
/// Both had their data sources running the whole time — the controllers were
/// never removed, only their rendering — so these tests are about the widgets
/// consuming state that already exists.
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
  // HTML on purpose: panels send markup and the bar has to flatten it.
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
///
/// `pumpAndSettle` is not usable once the ticker has two notices to rotate
/// through: it animates on a loop, so the tree is never idle.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Pumps a single page under a Scaffold, the way a page is always drawn.
Future<void> _pumpPage(
  WidgetTester tester,
  _NewsController controller,
  Widget page,
) async {
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
  testWidgets('the dashboard shows a notice and no banner without one', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      _NewsController(notices: const [_notice]),
      const V3DashboardPage(),
    );

    expect(find.byType(V3NoticeBar), findsOneWidget);
    // Title and body on one line, markup stripped: the raw content would have
    // shown the panel's `<b>` tags as literal text.
    expect(find.textContaining('服务公告'), findsOneWidget);
    expect(find.textContaining('<b>'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the notice bar renders nothing when there is no news', (
    tester,
  ) async {
    await _pumpPage(tester, _NewsController(), const V3DashboardPage());

    // The slot collapses rather than holding an empty card open: an empty
    // ticker reads as a broken one.
    expect(find.byType(V3NoticeBar), findsOneWidget);
    expect(find.text('查看'), findsNothing);
    expect(find.byIcon(Icons.campaign_rounded), findsNothing);
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
    // Nine seconds, not eight: the switcher cross-fades after the rotation.
    await tester.pump(const Duration(seconds: 9));
    expect(find.textContaining('维护通知'), findsOneWidget);

    // The ticker is a live animation from here on, so the tree has to come
    // down inside the test rather than being left to the framework.
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
    // Exact match, so this is the dialog's body and not the bar's one-liner.
    expect(find.text('香港、日本线路已完成优化。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(V3NoticeDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dashboard offers an update and drops it when dismissed', (
    tester,
  ) async {
    final controller = _NewsController(update: _update);
    await _pumpPage(tester, controller, const V3DashboardPage());

    expect(find.byType(V3UpdateBanner), findsOneWidget);
    expect(find.text('发现新版本 9.9.9'), findsOneWidget);
    expect(find.text('修复了若干问题'), findsOneWidget);

    // The label of the action button is deliberately not asserted: it differs
    // between desktop (install in place) and the rest (open the release page).
    await tester.tap(find.byTooltip('暂不提示'));
    await tester.pumpAndSettle();

    expect(controller.dismissals, 1);
    expect(find.text('发现新版本 9.9.9'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // The must-read tag (`弹窗`) had no effect for the whole rebuild: the
  // controller tracked the pending list and nothing rendered it.
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
    expect(find.text('隐私政策更新'), findsWidgets);

    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();

    expect(find.byType(V3NoticeDialog), findsNothing);
    expect(controller.seen, [9], reason: 'the popup must be marked seen');
    expect(tester.takeException(), isNull);
  });

  // Several must-reads queue rather than stacking: the next one waits for the
  // previous to be answered. The host guards "shown once" itself rather than
  // trusting the controller to have dropped it from the pending list by then.
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

    expect(find.text('隐私政策更新'), findsOneWidget);
    expect(find.text('服务条款更新'), findsNothing);

    await tester.tap(find.text('我知道了'));
    await _frames(tester);
    expect(controller.seen, [9]);
    expect(find.text('服务条款更新'), findsOneWidget);

    await tester.tap(find.text('我知道了'));
    await _frames(tester);
    expect(controller.seen, [9, 10]);
    expect(find.byType(V3NoticeDialog), findsNothing);

    // The ticker is mid-rotation and always will be; take the tree down here.
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  // A notice the user has already dismissed must not come back on the next
  // frame — and the host has to be present for that to mean anything, so this
  // asserts it is wired in rather than only that nothing appeared.
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
    expect(tester.takeException(), isNull);
  });
}

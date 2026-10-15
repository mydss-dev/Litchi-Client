import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_notice_carousel.dart';

import 'v3_visual_fixture.dart';

/// Round-3 audit N10: the phone dashboard's notice carousel had zero behavior
/// tests. These drive the real [V3NoticeCarousel] with a two-notice fixture
/// at 390x844 — the page tick, the hover pause (including after an arrow
/// tap, audit N16), and the reduced-motion promise.
class _CarouselNews extends VisualV3Controller {
  _CarouselNews({List<NoticeModel> notices = const []})
    : _live = notices,
      super(AppPage.dashboard);

  final List<NoticeModel> _live;

  @override
  List<NoticeModel> get notices => _live;
}

const _first = NoticeModel(
  id: 1,
  title: '公告甲',
  content: '第一条公告内容。',
  createdAt: 1789430400,
);

const _second = NoticeModel(
  id: 2,
  title: '公告乙',
  content: '第二条公告内容。',
  createdAt: 1789516800,
);

Future<void> _pumpCarousel(
  WidgetTester tester,
  VisualV3Controller controller, {
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(
    AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: disableAnimations,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: V3NoticeCarousel(controller: controller),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the phone dashboard mounts the carousel lane', (tester) async {
    // Widget tests default to android — the merged-card lane the carousel is
    // the real mount of. Assert the mount itself. The override is cleared in
    // the body: the framework checks foundation invariants before tear-downs.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.dashboard);
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: V3Theme.light(),
            home: const Scaffold(body: V3DashboardPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(V3NoticeCarousel), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('two notices open on the first page and the 6s tick advances', (
    tester,
  ) async {
    final controller = _CarouselNews(notices: const [_first, _second]);
    await _pumpCarousel(tester, controller);

    expect(find.text('公告甲'), findsOneWidget);
    expect(find.text('公告乙'), findsNothing);

    // The 6s clock does not fire on the frame that hits its exact 6s mark
    // (fake-async tickers need one more advancing frame), and the 320ms page
    // animation needs an epoch frame plus a completion frame; three 400ms
    // frames after the window expires cover all of it.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('公告乙'), findsOneWidget);
    // No absence check on 公告甲: a turned-away PageView page stays in the
    // element tree as a cached child inside the viewport's cacheExtent.
  });

  testWidgets('hovering the card pauses the 6s auto-advance', (tester) async {
    final controller = _CarouselNews(notices: const [_first, _second]);
    await _pumpCarousel(tester, controller);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(V3NoticeCarousel)));
    await tester.pump();

    await tester.pump(const Duration(seconds: 12));

    expect(find.text('公告甲'), findsOneWidget,
        reason: 'the hovered page stays put');
    expect(find.text('公告乙'), findsNothing);

    // Leaving the card resumes the tick through the same sync. The restarted
    // clock needs one advancing frame past its 6s window, then the page
    // animation needs an epoch frame plus a completion frame.
    await gesture.moveTo(const Offset(5, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('公告乙'), findsOneWidget,
        reason: 'leaving the card resumes the 6s tick');
  });

  testWidgets('an arrow tap while hovering does not re-arm the auto-advance', (
    tester,
  ) async {
    final controller = _CarouselNews(notices: const [_first, _second]);
    await _pumpCarousel(tester, controller);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(V3NoticeCarousel)));
    await tester.pump();

    // The page turns on demand under a hovering pointer. The tap schedules
    // the 320ms page animation; it needs an epoch frame to start and one to
    // finish.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('公告乙'), findsOneWidget);

    // ...and the re-sync that follows must not re-arm the 6s tick while the
    // pointer is still inside the card (audit N16).
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('公告乙'), findsOneWidget,
        reason: 'hover pauses the auto-advance even after an arrow tap');
  });

  testWidgets('reduced motion never starts the auto-advance timer', (tester) async {
    final controller = _CarouselNews(notices: const [_first, _second]);
    await _pumpCarousel(tester, controller, disableAnimations: true);

    await tester.pump(const Duration(seconds: 12));

    expect(find.text('公告甲'), findsOneWidget);
    expect(find.text('公告乙'), findsNothing);
  });

  testWidgets('both arrows are 44px targets with tooltips', (tester) async {
    final controller = _CarouselNews(notices: const [_first, _second]);
    await _pumpCarousel(tester, controller);

    expect(find.byTooltip('上一条'), findsOneWidget);
    expect(find.byTooltip('下一条'), findsOneWidget);
    for (final arrow in [find.byTooltip('上一条'), find.byTooltip('下一条')]) {
      final rect = tester.getRect(arrow);
      expect(rect.width, greaterThanOrEqualTo(44),
          reason: 'the arrow hit target is only ${rect.width}dp wide');
      expect(rect.height, greaterThanOrEqualTo(44),
          reason: 'the arrow hit target is only ${rect.height}dp tall');
    }
  });
}

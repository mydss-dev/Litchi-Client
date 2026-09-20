import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/auth/v3_auth_view.dart';
import 'package:litchi_client/v3/pages/v3_orders_page.dart';
import 'package:litchi_client/v3/pages/v3_tickets_page.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';

import 'visual/v3_visual_fixture.dart';

class _ExpiredSessionController extends VisualV3Controller {
  _ExpiredSessionController() : super(AppPage.dashboard);
  String? _message = '会话已过期，请重新登录';

  @override
  bool get isAuthenticated => false;
  @override
  String? get startupMessage => _message;
  @override
  void clearStartupMessage() => _message = null;
}

class _RecentHistoryController extends VisualV3Controller {
  _RecentHistoryController() : super(AppPage.traffic);

  @override
  List<TrafficUsagePoint> get trafficUsage {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(30, (index) {
      return TrafficUsagePoint(
        date: today.subtract(Duration(days: 29 - index)),
        totalGb: 1.0 + index / 10,
      );
    });
  }
}

Future<void> _show(WidgetTester tester, VisualV3Controller controller,
    Widget page, {Size size = const Size(390, 900)}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(home: Scaffold(body: page)),
  ));
  await tester.pump();
}

void main() {
  testWidgets('expired session is explained once on the login view', (tester) async {
    final controller = _ExpiredSessionController();
    await _show(tester, controller, const V3AuthView());
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('会话已过期，请重新登录'), findsOneWidget);
    expect(controller.startupMessage, isNull);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('会话已过期，请重新登录'), findsNothing);
  });

  testWidgets('phone orders expose pay and cancel without an overflow menu',
      (tester) async {
    final controller = VisualV3Controller(AppPage.orders);
    await _show(tester, controller,
      const SingleChildScrollView(child: V3OrdersPage()),
      size: const Size(390, 1400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v3-order-phone-row')), findsWidgets);
    expect(find.byKey(const Key('v3-order-phone-pay')), findsOneWidget);
    expect(find.byKey(const Key('v3-order-phone-cancel')), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone tickets use a two-line subject row', (tester) async {
    final controller = VisualV3Controller(AppPage.tickets);
    await _show(tester, controller, const V3TicketsPage());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('v3-ticket-phone-row')), findsWidgets);
    final title = tester.widget<Text>(find.text('香港节点连接问题'));
    expect(title.maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('traffic history opens scrolled to the latest date',
      (tester) async {
    final controller = _RecentHistoryController();
    await _show(tester, controller, const V3TrafficPage());
    await tester.ensureVisible(find.text('30天'));
    await tester.tap(find.text('30天'));
    await tester.pumpAndSettle();
    final view = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('v3-traffic-trend-scroll')));
    expect(view.controller, isNotNull);
    expect(view.controller!.offset, greaterThan(0));
    expect(find.byKey(const Key('v3-traffic-yesterday-comparison')),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

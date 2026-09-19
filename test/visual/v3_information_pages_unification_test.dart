import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/pages/v3_invite_page.dart';
import 'package:litchi_client/v3/pages/v3_settings_page.dart';
import 'package:litchi_client/v3/pages/v3_tickets_page.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _ReadyTickets extends VisualV3Controller {
  _ReadyTickets() : super(AppPage.tickets);

  @override
  bool get ticketsLoaded => true;
  @override
  bool get ticketsLoading => false;
  @override
  String? get ticketsError => null;
  @override
  List<TicketModel> get tickets => const [];
  @override
  Future<void> refreshTickets() async {}
}

Future<void> _show(WidgetTester tester, Widget page,
    VisualV3Controller controller, Size size, ThemeMode mode) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(
      theme: V3Theme.light(),
      darkTheme: V3Theme.dark(),
      themeMode: mode,
      home: Scaffold(body: page),
    ),
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  const layouts = [
    (Size(688, 700), ThemeMode.light),
    (Size(360, 800), ThemeMode.dark),
  ];

  for (final (size, mode) in layouts) {
    testWidgets('traffic keeps real values and 7/15/30 selector at $size $mode',
        (tester) async {
      await _show(tester, const V3TrafficPage(),
          VisualV3Controller(AppPage.traffic), size, mode);
      expect(find.text('剩余流量'), findsOneWidget);
      final periods = find.byType(SegmentedButton<int>);
      expect(periods, findsOneWidget);
      expect(tester.widget<SegmentedButton<int>>(periods).selected, {7});
      final fifteen = find.text('15天');
      await tester.ensureVisible(fifteen);
      await tester.pumpAndSettle();
      await tester.tap(fifteen);
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<int>>(periods).selected, {15});
      expect(tester.takeException(), isNull);
    });

    testWidgets('invite preserves code and share actions at $size $mode',
        (tester) async {
      await _show(tester, const V3InvitePage(),
          VisualV3Controller(AppPage.invite), size, mode);
      expect(find.text('LITCHI88'), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-invite-copy-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('v3-invite-copy-link')), findsOneWidget);
      expect(find.text('最近返佣记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tickets retain new ticket and statuses at $size $mode',
        (tester) async {
      await _show(tester, const V3TicketsPage(), _ReadyTickets(), size, mode);
      expect(find.text('支持工单'), findsOneWidget);
      expect(find.text('新建工单'), findsOneWidget);
      expect(find.text('全部工单'), findsOneWidget);
      expect(find.text('处理中'), findsOneWidget);
      expect(find.text('已关闭'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('settings keep controls without decorative indices at $size $mode',
        (tester) async {
      await _show(tester, const V3SettingsPage(),
          VisualV3Controller(AppPage.settings), size, mode);
      expect(find.text('01'), findsNothing);
      expect(find.text('02'), findsNothing);
      expect(find.text('03'), findsNothing);
      expect(find.text('网络设置'), findsNothing); // No invented navigation section.
      expect(find.byType(AnimatedAlign), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}

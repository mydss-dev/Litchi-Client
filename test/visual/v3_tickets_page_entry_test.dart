import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/pages/v3_tickets_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

class _TicketListController extends VisualV3Controller {
  _TicketListController() : super(AppPage.tickets);

  bool loaded = false;

  @override
  bool get ticketsLoaded => loaded;
  @override
  bool get ticketsLoading => !loaded;
  @override
  String? get ticketsError => null;
  @override
  List<TicketModel> get tickets => loaded
      ? const [
          TicketModel(
            id: 101,
            subject: '香港节点连接问题',
            level: 1,
            status: 0,
            createdAt: 1789430400,
            updatedAt: 1789430400,
          ),
        ]
      : const [];
  @override
  Future<void> refreshTickets() async {}

  void finishLoading() {
    loaded = true;
    notifyListeners();
  }
}

void main() {
  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    testWidgets('ticket page header stays in place during list load $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _TicketListController();
      addTearDown(controller.disposeVisual);
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: V3Theme.light(),
            home: const Scaffold(body: V3TicketsPage()),
          ),
        ),
      );
      await tester.pump();
      final heading = find.text('支持工单');
      final before = tester.getTopLeft(heading);
      controller.finishLoading();
      await tester.pump();
      expect(tester.getTopLeft(heading), before);
      expect(find.text('香港节点连接问题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

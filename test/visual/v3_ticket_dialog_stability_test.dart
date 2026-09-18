import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/shared/services/api_client.dart';
import 'package:litchi_client/shared/services/panel_api.dart';
import 'package:litchi_client/v3/pages/v3_ticket_detail_dialog.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

const _summary = TicketModel(
  id: 101,
  subject: '香港节点连接问题',
  level: 1,
  status: 0,
  createdAt: 1789430400,
  updatedAt: 1789430400,
);

const _detail = TicketModel(
  id: 101,
  subject: '香港节点连接问题',
  level: 1,
  status: 0,
  createdAt: 1789430400,
  updatedAt: 1789430400,
  messages: [
    TicketMessageModel(
      id: 1,
      isAdmin: true,
      message: '已排查线路',
      createdAt: 1789430400,
    ),
  ],
);

class _DelayedTicketApi extends PanelApi {
  _DelayedTicketApi() : super(ApiClient());

  final first = Completer<TicketModel>();
  final second = Completer<TicketModel>();
  int requests = 0;

  @override
  Future<TicketModel> getTicketDetail(int ticketId) {
    expect(ticketId, 101);
    return (requests++ == 0 ? first : second).future;
  }
}

Future<void> _pumpDialog(
  WidgetTester tester,
  _DelayedTicketApi api,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: V3Theme.light(),
      home: Scaffold(
        body: V3TicketDetailDialog(
          summary: _summary,
          api: api,
          onChanged: () async {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void _assertFixedGeometry(
  WidgetTester tester,
  Rect frame,
  Offset title,
) {
  expect(
    tester.getRect(find.byKey(const ValueKey('v3-ticket-dialog-frame'))),
    frame,
    reason: 'The dialog frame must not resize as content arrives',
  );
  expect(
    tester.getTopLeft(find.byKey(const ValueKey('v3-ticket-dialog-title'))),
    title,
    reason: 'The ticket title must not jump while details load',
  );
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [const Size(900, 700), const Size(390, 844)]) {
    testWidgets('ticket dialog is stable during first load at $size', (
      tester,
    ) async {
      final api = _DelayedTicketApi();
      await _pumpDialog(tester, api, size);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('香港节点连接问题'), findsOneWidget);
      final frame = tester.getRect(
        find.byKey(const ValueKey('v3-ticket-dialog-frame')),
      );
      final title = tester.getTopLeft(
        find.byKey(const ValueKey('v3-ticket-dialog-title')),
      );

      api.first.complete(_detail);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('已排查线路'), findsOneWidget);
      _assertFixedGeometry(tester, frame, title);
    });
  }

  testWidgets('load failure and retry do not resize or move ticket title', (
    tester,
  ) async {
    final api = _DelayedTicketApi();
    await _pumpDialog(tester, api, const Size(900, 700));
    final frame = tester.getRect(
      find.byKey(const ValueKey('v3-ticket-dialog-frame')),
    );
    final title = tester.getTopLeft(
      find.byKey(const ValueKey('v3-ticket-dialog-title')),
    );

    api.first.completeError(Exception('网络中断'));
    await tester.pump();
    await tester.pump();
    expect(find.text('无法打开工单'), findsOneWidget);
    _assertFixedGeometry(tester, frame, title);

    await tester.tap(find.text('重试'));
    await tester.pump();
    _assertFixedGeometry(tester, frame, title);
    api.second.complete(_detail);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('已排查线路'), findsOneWidget);
    _assertFixedGeometry(tester, frame, title);
  });
}

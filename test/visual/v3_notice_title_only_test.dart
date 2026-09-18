import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/api_models.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_notice_bar.dart';

import 'v3_visual_fixture.dart';

class _Controller extends VisualV3Controller {
  _Controller() : super(AppPage.dashboard);

  @override
  List<NoticeModel> get notices => const [
    NoticeModel(
      id: 101,
      title: '服务公告',
      content: '<p>正文只能在公告详情中看到。</p>',
      createdAt: 1789430400,
    ),
  ];
}

void main() {
  testWidgets('ticker shows title only; reader retains full description', (tester) async {
    final controller = _Controller();
    addTearDown(controller.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(body: V3NoticeBar(controller: controller)),
      ),
    ));

    expect(find.text('服务公告'), findsOneWidget);
    expect(find.textContaining('正文只能在公告详情中看到'), findsNothing);

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();
    expect(find.byType(V3NoticeDialog), findsOneWidget);
    expect(find.text('正文只能在公告详情中看到。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(V3NoticeDialog), findsNothing);
  });
}

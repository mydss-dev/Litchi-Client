import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

void main() {
  testWidgets('usage chart switches 7/15/30 days without opening dialogs',
      (tester) async {
    final controller = VisualV3Controller(AppPage.traffic);
    addTearDown(controller.disposeVisual);
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(AppScope(
      controller: controller,
      child: MaterialApp(
        theme: V3Theme.light(),
        home: const Scaffold(body: V3TrafficPage()),
      ),
    ));
    await tester.pump();

    expect(kV3TrafficPeriods, [7, 15, 30]);
    final selector = find.byType(SegmentedButton<int>);
    expect(tester.widget<SegmentedButton<int>>(selector).selected, {7});

    await tester.tap(find.text('15天'));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<int>>(selector).selected, {15});

    await tester.tap(find.text('30天'));
    await tester.pumpAndSettle();
    expect(tester.widget<SegmentedButton<int>>(selector).selected, {30});

    final usageTips = find.byWidgetPredicate((widget) =>
      widget is Tooltip && widget.message?.contains('GB') == true);
    expect(usageTips, findsWidgets);
    await tester.tap(usageTips.first);
    await tester.pump();
    expect(find.byType(Dialog), findsNothing,
      reason: 'traffic details belong in hover tooltips, not tap dialogs');
    expect(tester.takeException(), isNull);
  });
}

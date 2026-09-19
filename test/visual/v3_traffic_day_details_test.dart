import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/v3/pages/v3_traffic_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

String _day(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _TrafficController extends VisualV3Controller {
  _TrafficController(this.directional) : super(AppPage.traffic);
  final bool directional;

  @override
  List<double> get dailyUsage => const [];

  @override
  List<TrafficUsagePoint> get trafficUsage => [
    TrafficUsagePoint(
      date: DateTime.now().subtract(const Duration(days: 1)),
      totalGb: 2,
      uploadGb: directional ? 0.5 : 0,
      downloadGb: directional ? 1.5 : 0,
    ),
  ];
}

Future<void> _pump(WidgetTester tester, _TrafficController controller) async {
  await tester.binding.setSurfaceSize(const Size(900, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(AppScope(
    controller: controller,
    child: MaterialApp(
      theme: V3Theme.light(),
      home: const Scaffold(body: V3TrafficPage()),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _dayTooltip(String day) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && widget.message?.startsWith('$day\n') == true,
  description: 'traffic tooltip for $day',
);

void main() {
  testWidgets('daily bar tooltip contains actual total and directional metrics',
      (tester) async {
    await _pump(tester, _TrafficController(true));
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    final tooltip = _dayTooltip(yesterday);
    expect(tooltip, findsOneWidget);
    expect(tester.widget<Tooltip>(tooltip).message,
      '$yesterday\n2.00 GB\n上传 0.50 GB · 下载 1.50 GB');

    await tester.ensureVisible(tooltip);
    await tester.tap(tooltip);
    await tester.pump();
    expect(find.byType(Dialog), findsNothing,
      reason: 'day details are tooltips, not tap-triggered dialogs');
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing directional data is not represented as measured zero',
      (tester) async {
    await _pump(tester, _TrafficController(false));
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    final tooltip = _dayTooltip(yesterday);
    expect(tooltip, findsOneWidget);
    final message = tester.widget<Tooltip>(tooltip).message;
    expect(message, '$yesterday\n2.00 GB');
    expect(message, isNot(contains('上传 0.00 GB')));
    expect(message, isNot(contains('下载 0.00 GB')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing calendar day is not shown as zero usage', (tester) async {
    await _pump(tester, _TrafficController(true));
    final missing = _day(DateTime.now().subtract(const Duration(days: 2)));
    final tooltip = _dayTooltip(missing);
    expect(tooltip, findsOneWidget);
    final message = tester.widget<Tooltip>(tooltip).message;
    expect(message, '$missing\n暂无记录');
    expect(message, isNot(contains('0.00 GB')));
    expect(tester.takeException(), isNull);
  });
}

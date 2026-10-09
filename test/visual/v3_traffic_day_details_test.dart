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

class _PinnedController extends VisualV3Controller {
  _PinnedController() : super(AppPage.traffic);

  @override
  List<double> get dailyUsage => const [];

  @override
  List<TrafficUsagePoint> get trafficUsage => [
    TrafficUsagePoint(
      date: DateTime.now().subtract(const Duration(days: 2)),
      totalGb: 1.25,
      uploadGb: 0.25,
      downloadGb: 1.0,
    ),
    TrafficUsagePoint(
      date: DateTime.now().subtract(const Duration(days: 1)),
      totalGb: 3.75,
      uploadGb: 0.75,
      downloadGb: 3.0,
    ),
  ];
}

Future<void> _pump(WidgetTester tester, VisualV3Controller controller) async {
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

  // The pinned readout makes the bar numbers readable without hover (M3/HIG:
  // a tooltip is a desktop supplement, never the only carrier). Tapping a bar
  // pins its day; the readout defaults to the latest recorded day.
  testWidgets('tapping a bar pins the day readout above the chart',
      (tester) async {
    await _pump(tester, _PinnedController());
    final twoDaysAgo = _day(DateTime.now().subtract(const Duration(days: 2)));
    // Default readout: the most recent day that has a record.
    expect(find.text('上传 0.75 GB · 下载 3.00 GB'), findsOneWidget);
    expect(find.text('3.75 GB'), findsOneWidget);

    await tester.ensureVisible(_dayTooltip(twoDaysAgo));
    await tester.tap(_dayTooltip(twoDaysAgo));
    await tester.pump();
    expect(find.text('上传 0.25 GB · 下载 1.00 GB'), findsOneWidget);
    expect(find.text('1.25 GB'), findsOneWidget);
    expect(find.text(twoDaysAgo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

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

void main() {
  testWidgets('daily bar opens actual total and directional metrics', (tester) async {
    await _pump(tester, _TrafficController(true));
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    final bar = find.byKey(ValueKey('v3-traffic-day-$yesterday'));
    expect(bar, findsOneWidget);
    await tester.ensureVisible(bar);
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text('流量详情 · $yesterday'), findsOneWidget);
    expect(find.text('该日总流�?2.00 GB'), findsOneWidget);
    expect(find.text('上传 0.50 GB'), findsOneWidget);
    expect(find.text('下载 1.50 GB'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing directional data is not represented as measured zero',
      (tester) async {
    await _pump(tester, _TrafficController(false));
    final yesterday = _day(DateTime.now().subtract(const Duration(days: 1)));
    final bar = find.byKey(ValueKey('v3-traffic-day-$yesterday'));
    await tester.ensureVisible(bar);
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text('该日总流�?2.00 GB'), findsOneWidget);
    expect(find.text('后台未提供上传、下载明�?), findsOneWidget);
    expect(find.text('上传 0.00 GB'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing calendar day is not shown as zero usage', (tester) async {
    await _pump(tester, _TrafficController(true));
    final missing = _day(DateTime.now().subtract(const Duration(days: 2)));
    final bar = find.byKey(ValueKey('v3-traffic-day-$missing'));
    expect(bar, findsOneWidget);
    await tester.ensureVisible(bar);
    await tester.tap(bar);
    await tester.pumpAndSettle();
    expect(find.text('该日暂无记录'), findsOneWidget);
    expect(find.text('该日总流�?0.00 GB'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

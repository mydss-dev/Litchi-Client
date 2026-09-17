import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/services/traffic_history_series.dart';

void main() {
  final today = DateTime(2026, 9, 17);

  test('30-day selection retains all calendar positions with 15 server days', () {
    final logs = [
      for (var i = 0; i < 15; i++)
        TrafficUsagePoint(
          date: today.subtract(Duration(days: i)),
          totalGb: 2,
        ),
    ];
    final series = TrafficHistorySeries.build(
      windowDays: 30,
      trafficUsage: logs,
      dailyUsage: const [],
      now: today,
    );
    expect(series.days, hasLength(30));
    expect(series.days.first.date, DateTime(2026, 8, 19));
    expect(series.days.last.date, today);
    expect(series.days.first.gb, isNull);
    expect(series.days.last.gb, 2);
    expect(series.recordedDays, 15);
    expect(series.hasGaps, isTrue);
    expect(series.totalGb, 30);
    expect(series.averageGb, 2);
  });

  test('explicit zero usage differs from a missing calendar date', () {
    final series = TrafficHistorySeries.build(
      windowDays: 7,
      trafficUsage: [TrafficUsagePoint(date: today, totalGb: 0)],
      dailyUsage: const [],
      now: today,
    );
    expect(series.recordedDays, 1);
    expect(series.days.first.gb, isNull);
    expect(series.days.last.gb, 0);
  });

  test('duplicate dated logs aggregate while future logs are ignored', () {
    final series = TrafficHistorySeries.build(
      windowDays: 7,
      trafficUsage: [
        TrafficUsagePoint(date: today, totalGb: 1),
        TrafficUsagePoint(date: today, totalGb: 3),
        TrafficUsagePoint(date: today.add(const Duration(days: 1)), totalGb: 99),
      ],
      dailyUsage: const [],
      now: today,
    );
    expect(series.recordedDays, 1);
    expect(series.days.last.gb, 4);
    expect(series.totalGb, 4);
  });

  test('undated 15-entry fallback does not pretend to have 30 records', () {
    final series = TrafficHistorySeries.build(
      windowDays: 30,
      trafficUsage: const [],
      dailyUsage: List.filled(15, 1),
      now: today,
    );
    expect(series.days, hasLength(30));
    expect(series.recordedDays, 15);
    expect(series.days.first.gb, isNull);
    expect(series.days.last.gb, 1);
  });
}

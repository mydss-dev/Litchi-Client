import '../models/app_models.dart';

/// A calendar slot can have no history. Null is deliberately distinct from 0:
/// the API omitting a day does not establish that no traffic was used.
class TrafficHistoryDay {
  const TrafficHistoryDay({required this.date, required this.gb});

  final DateTime date;
  final double? gb;
}

class TrafficHistorySeries {
  const TrafficHistorySeries(this.days);

  final List<TrafficHistoryDay> days;

  int get recordedDays => days.where((day) => day.gb != null).length;
  bool get hasGaps => recordedDays < days.length;
  double get totalGb => days.fold<double>(
    0.0, (sum, day) => sum + (day.gb ?? 0.0));
  double get averageGb => recordedDays == 0 ? 0.0 : totalGb / recordedDays;
  double get maxGb => days.fold<double>(0.0, (max, day) {
    final gb = day.gb ?? 0.0;
    return gb > max ? gb : max;
  });

  /// Build precisely [windowDays] consecutive dates, including unreported days.
  /// Prefer dated server logs; the legacy undated fallback is anchored to today
  /// as it was previously, but its unknown earlier days remain null.
  static TrafficHistorySeries build({
    required int windowDays,
    required List<TrafficUsagePoint> trafficUsage,
    required List<double> dailyUsage,
    DateTime? now,
  }) {
    assert(windowDays > 0);
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final first = today.subtract(Duration(days: windowDays - 1));
    final amounts = <DateTime, double>{};
    if (trafficUsage.isNotEmpty) {
      for (final point in trafficUsage) {
        final date = DateTime(point.date.year, point.date.month, point.date.day);
        if (date.isBefore(first) || date.isAfter(today)) continue;
        amounts[date] = (amounts[date] ?? 0.0) + point.totalGb;
      }
    } else {
      final length = dailyUsage.length < windowDays
          ? dailyUsage.length
          : windowDays;
      final start = dailyUsage.length - length;
      for (var i = 0; i < length; i++) {
        amounts[today.subtract(Duration(days: length - i - 1))] =
            dailyUsage[start + i];
      }
    }
    return TrafficHistorySeries([
      for (var offset = 0; offset < windowDays; offset++)
        TrafficHistoryDay(
          date: first.add(Duration(days: offset)),
          gb: amounts[first.add(Duration(days: offset))],
        ),
    ]);
  }
}

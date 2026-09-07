import '../models/app_models.dart';

/// Returns the total traffic recorded for one local calendar day.
double trafficForDay(List<TrafficUsagePoint> usage, DateTime day) {
  var total = 0.0;
  for (final point in usage) {
    final date = point.date;
    if (date.year == day.year &&
        date.month == day.month &&
        date.day == day.day) {
      total += point.totalGb;
    }
  }
  return total;
}

/// Relative change in percent. Returns null when there is no meaningful
/// previous-day baseline, avoiding an invalid divide-by-zero comparison.
double? relativeChangePercent({
  required double current,
  required double previous,
}) {
  if (previous <= 0) return null;
  return (current - previous) / previous * 100;
}

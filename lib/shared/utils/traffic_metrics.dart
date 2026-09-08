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

/// Resolves the subscription expiry date from the API timestamp first and the
/// legacy user-facing expiry string second.
DateTime? subscriptionExpiryDate({
  required int? expiredAt,
  required String expiryText,
}) {
  if (expiredAt != null && expiredAt > 0) {
    return DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000);
  }
  return DateTime.tryParse(expiryText);
}

/// Whole local-calendar days until [expiry], clamped at zero for expired plans.
int daysUntilDate(DateTime expiry, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final end = DateTime(expiry.year, expiry.month, expiry.day);
  return end.difference(today).inDays.clamp(0, 9999);
}

int? validResetDay(int? resetDay) {
  if (resetDay == null || resetDay < 1 || resetDay > 31) return null;
  return resetDay;
}

/// Days until the monthly reset. The reset day itself deliberately returns 0.
int daysUntilMonthlyReset(int resetDay, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  var target = _safeMonthlyDate(current.year, current.month, resetDay);
  if (target.isBefore(today)) {
    final nextMonth = DateTime(current.year, current.month + 1, 1);
    target = _safeMonthlyDate(nextMonth.year, nextMonth.month, resetDay);
  }
  return target.difference(today).inDays;
}

DateTime _safeMonthlyDate(int year, int month, int requestedDay) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = requestedDay.clamp(1, lastDay).toInt();
  return DateTime(year, month, day);
}

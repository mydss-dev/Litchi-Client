import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';
import '../models/app_models.dart';
import 'formatters.dart';
import 'traffic_metrics.dart';

String yesterdayComparisonText(
  BuildContext context, {
  required List<TrafficUsagePoint> usage,
  required double currentGb,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final yesterday = trafficForDay(
    usage,
    current.subtract(const Duration(days: 1)),
  );
  final change = relativeChangePercent(current: currentGb, previous: yesterday);
  if (change == null) {
    return context.l10n.yesterdayUsageLabel(formatGb(yesterday));
  }
  final rounded = change.abs() < 0.5 ? 0 : change.round();
  final signed = rounded > 0 ? '+$rounded%' : '$rounded%';
  return context.l10n.comparedYesterdayLabel(signed);
}

({int? days, String date}) subscriptionExpiryDisplay({
  required int? expiredAt,
  required String expiryText,
  DateTime? now,
}) {
  final expiry = subscriptionExpiryDate(
    expiredAt: expiredAt,
    expiryText: expiryText,
  );
  if (expiry == null) return (days: null, date: '');
  return (days: daysUntilDate(expiry, now: now), date: formatDate(expiry));
}

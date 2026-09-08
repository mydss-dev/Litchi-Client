import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/app_models.dart';
import 'package:litchi_client/shared/utils/traffic_metrics.dart';

void main() {
  group('trafficForDay', () {
    test('sums multiple points from the same local day only', () {
      final usage = [
        TrafficUsagePoint(date: DateTime(2026, 9, 8, 8), totalGb: 1.25),
        TrafficUsagePoint(date: DateTime(2026, 9, 8, 20), totalGb: 0.75),
        TrafficUsagePoint(date: DateTime(2026, 9, 7, 23), totalGb: 9),
      ];

      expect(trafficForDay(usage, DateTime(2026, 9, 8)), 2.0);
    });
  });

  group('relativeChangePercent', () {
    test('returns null without a positive baseline', () {
      expect(relativeChangePercent(current: 2, previous: 0), isNull);
      expect(relativeChangePercent(current: 2, previous: -1), isNull);
    });

    test('calculates increases and decreases', () {
      expect(relativeChangePercent(current: 3, previous: 2), 50);
      expect(relativeChangePercent(current: 1, previous: 2), -50);
    });
  });

  group('subscription expiry', () {
    test('prefers the API timestamp', () {
      final expiry = subscriptionExpiryDate(
        expiredAt: DateTime(2026, 10, 3).millisecondsSinceEpoch ~/ 1000,
        expiryText: '2030-01-01',
      );
      expect(expiry, isNotNull);
      expect(expiry!.year, 2026);
      expect(expiry.month, 10);
      expect(expiry.day, 3);
    });

    test('falls back to expiry text', () {
      expect(
        subscriptionExpiryDate(expiredAt: null, expiryText: '2026-10-03'),
        DateTime(2026, 10, 3),
      );
    });

    test('daysUntilDate uses calendar days and clamps expired values', () {
      expect(
        daysUntilDate(DateTime(2026, 9, 10, 1), now: DateTime(2026, 9, 8, 23)),
        2,
      );
      expect(daysUntilDate(DateTime(2026, 9, 7), now: DateTime(2026, 9, 8)), 0);
    });
  });

  group('monthly reset countdown', () {
    test('validates reset day', () {
      expect(validResetDay(null), isNull);
      expect(validResetDay(0), isNull);
      expect(validResetDay(32), isNull);
      expect(validResetDay(31), 31);
    });

    test('returns zero on the reset day', () {
      expect(daysUntilMonthlyReset(8, now: DateTime(2026, 9, 8, 18)), 0);
    });

    test('rolls to next month after reset day', () {
      expect(daysUntilMonthlyReset(8, now: DateTime(2026, 9, 9)), 29);
    });

    test('clamps day 31 to the last day of a shorter month', () {
      expect(daysUntilMonthlyReset(31, now: DateTime(2026, 2, 1)), 27);
    });
  });
}

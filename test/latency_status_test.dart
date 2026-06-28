import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/utils/latency_status.dart';

void main() {
  test('classifies latency using FlClash-compatible thresholds', () {
    expect(LatencyStatus.quality(0), LatencyQuality.untested);
    expect(LatencyStatus.quality(-1), LatencyQuality.testing);
    expect(LatencyStatus.quality(1), LatencyQuality.good);
    expect(LatencyStatus.quality(300), LatencyQuality.good);
    expect(LatencyStatus.quality(599), LatencyQuality.good);
    expect(LatencyStatus.quality(600), LatencyQuality.slow);
    expect(LatencyStatus.quality(9998), LatencyQuality.slow);
    expect(LatencyStatus.quality(9999), LatencyQuality.timeout);
  });

  test('formats latency labels consistently', () {
    expect(LatencyStatus.label(-1), isEmpty);
    expect(LatencyStatus.label(0), '--');
    expect(LatencyStatus.label(300), '300 ms');
    expect(LatencyStatus.label(9999), '超时');
  });
}

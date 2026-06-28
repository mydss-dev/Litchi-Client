import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum LatencyQuality { untested, testing, good, slow, timeout }

abstract final class LatencyStatus {
  static const int slowThresholdMs = 600;
  static const int timeoutValue = 9999;

  static LatencyQuality quality(int? latency) {
    if (latency == null || latency == 0) return LatencyQuality.untested;
    if (latency < 0) return LatencyQuality.testing;
    if (latency >= timeoutValue) return LatencyQuality.timeout;
    if (latency < slowThresholdMs) return LatencyQuality.good;
    return LatencyQuality.slow;
  }

  static Color color(int? latency, AppColors colors) {
    return switch (quality(latency)) {
      LatencyQuality.untested => colors.textMuted,
      LatencyQuality.testing => colors.warning,
      LatencyQuality.good => colors.success,
      LatencyQuality.slow => colors.warning,
      LatencyQuality.timeout => colors.danger,
    };
  }

  static String label(int latency) {
    return switch (quality(latency)) {
      LatencyQuality.testing => '',
      LatencyQuality.untested => '--',
      LatencyQuality.timeout => '超时',
      _ => '$latency ms',
    };
  }
}

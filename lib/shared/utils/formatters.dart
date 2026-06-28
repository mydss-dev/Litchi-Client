import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Formats a [Duration] as zero-padded `HH:MM:SS`.
String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

/// Formats gigabytes for traffic cards (`X.X GB`).
String formatTrafficGb(double gb) {
  if (gb <= 0) return '0.0 GB';
  return '${gb.toStringAsFixed(1)} GB';
}

/// Formats bytes-per-second for the speedometer (`X MB/s` / `X KB/s` / `X B/s`).
String formatRate(int bps) {
  if (bps <= 0) return '0 KB/s';
  const kb = 1024;
  const mb = 1024 * 1024;
  if (bps >= mb) return '${(bps / mb).toStringAsFixed(1)} MB/s';
  if (bps >= kb) return '${(bps / kb).toStringAsFixed(0)} KB/s';
  return '$bps B/s';
}

/// Formats a reset-day integer for display.
///
/// Returns `--` when null or 0; otherwise `每月 X 日`.
String formatResetDay(int? resetDay) {
  if (resetDay == null || resetDay == 0) return '--';
  return '每月 $resetDay 日';
}

/// Formats a device-limit integer for display.
///
/// Returns `--` when null, `不限` when 0, otherwise `X 台`.
String formatDeviceLimit(int? deviceLimit) {
  if (deviceLimit == null) return '--';
  return deviceLimit > 0 ? '$deviceLimit 台' : '不限';
}

/// Formats a [DateTime] as `YYYY-MM-DD`.
String formatDate(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

/// Formats gigabytes with sub-GB fallback to MB for precision.
///
/// - 0 → `0 GB`
/// - < 0.01 → `X.X MB`
/// - < 1 → `X.XX GB`
/// - ≥ 1 → `X.X GB`
String formatGb(double value) {
  if (value == 0) return '0 GB';
  if (value < 0.01) return '${(value * 1024).toStringAsFixed(1)} MB';
  if (value < 1) return '${value.toStringAsFixed(2)} GB';
  return '${value.toStringAsFixed(1)} GB';
}

/// Returns the appropriate [IconData] for a home-card metric.
IconData homeCardIcon(String icon, String type) {
  final name = icon.isEmpty ? type : icon;
  return switch (name) {
    'package' => LucideIcons.package,
    'gauge' => LucideIcons.gauge,
    'calendarDays' => LucideIcons.calendarDays,
    'calendarClock' => LucideIcons.calendarClock,
    'refreshCw' => LucideIcons.refreshCw,
    'download' => LucideIcons.download,
    'upload' => LucideIcons.upload,
    'smartphone' => LucideIcons.smartphone,
    'timer' => LucideIcons.timer,
    'activity' => LucideIcons.activity,
    'zap' => LucideIcons.zap,
    'currentPlan' => LucideIcons.package,
    'remainTraffic' => LucideIcons.gauge,
    'todayTraffic' => LucideIcons.calendarDays,
    'downSpeed' => LucideIcons.download,
    'upSpeed' => LucideIcons.upload,
    'resetDay' => LucideIcons.refreshCw,
    'deviceLimit' => LucideIcons.smartphone,
    'expireDate' => LucideIcons.calendarClock,
    _ => LucideIcons.gauge,
  };
}

/// Returns the Chinese-language label for a home-card type.
String homeCardTitle(String type) {
  return switch (type) {
    'currentPlan' => '当前套餐',
    'remainTraffic' => '剩余流量',
    'todayTraffic' => '今日流量',
    'downSpeed' => '下行速率',
    'upSpeed' => '上行速率',
    'resetDay' => '流量重置',
    'deviceLimit' => '设备数',
    'expireDate' => '到期时间',
    _ => '信息',
  };
}

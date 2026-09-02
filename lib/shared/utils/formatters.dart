/// Formats a [Duration] as zero-padded `HH:MM:SS`.
String formatDuration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
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

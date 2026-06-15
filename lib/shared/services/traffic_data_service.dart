import '../config/app_config.dart';
import '../models/api_models.dart';
import '../models/app_models.dart';
import 'panel_api.dart';

class TrafficLogDataResult {
  const TrafficLogDataResult({
    this.dailyUsage = const [],
    this.trafficUsage = const [],
  });

  final List<double> dailyUsage;
  final List<TrafficUsagePoint> trafficUsage;
}

class TrafficDataService {
  const TrafficDataService(this._api);

  final PanelApi _api;

  Future<TrafficLogDataResult> loadTrafficLog() async {
    final logs = await _api.getTrafficLog();
    return fromLogs(logs);
  }

  static TrafficLogDataResult fromLogs(List<RemoteTrafficLog> logs) {
    if (logs.isEmpty) return const TrafficLogDataResult();

    final totalDaily = <DateTime, double>{};
    final uploadDaily = <DateTime, double>{};
    final downloadDaily = <DateTime, double>{};
    for (final log in logs) {
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      totalDaily[date] =
          (totalDaily[date] ?? 0) + log.traffic / AppConfig.bytesPerGb;
      uploadDaily[date] =
          (uploadDaily[date] ?? 0) + log.upload / AppConfig.bytesPerGb;
      downloadDaily[date] =
          (downloadDaily[date] ?? 0) + log.download / AppConfig.bytesPerGb;
    }

    final points =
        totalDaily.entries
            .map(
              (entry) => TrafficUsagePoint(
                date: entry.key,
                totalGb: entry.value,
                uploadGb: uploadDaily[entry.key] ?? 0,
                downloadGb: downloadDaily[entry.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    return TrafficLogDataResult(
      trafficUsage: points,
      dailyUsage: points.map((point) => point.totalGb).toList(),
    );
  }
}

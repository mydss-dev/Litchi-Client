from pathlib import Path

path = Path('lib/v3/pages/v3_traffic_page.dart')
source = path.read_text(encoding='utf-8')
old = '''          value: yesterdayComparisonText(context,
            usage: controller.trafficUsage,
            currentGb: controller.todayTrafficGb), accent: p.aqua),'''
new = '''          value: _v3YesterdayComparison(context, controller.trafficUsage,
            controller.todayTrafficGb), accent: p.aqua),'''
assert source.count(old) == 1, 'Could not locate yesterday comparison call'
source = source.replace(old, new, 1)
old_import = "import '../../shared/utils/traffic_summary_text.dart';"
assert source.count(old_import) == 1
source = source.replace(old_import, old_import + "\nimport '../../shared/utils/traffic_metrics.dart';", 1)
source += '''

/// V3 copy must also render in isolated widget previews without ARB delegates.
String _v3YesterdayComparison(BuildContext context,
    List<TrafficUsagePoint> usage, double today) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final hasRecord = usage.any((point) =>
    point.date.year == yesterday.year &&
    point.date.month == yesterday.month && point.date.day == yesterday.day);
  if (!hasRecord) {
    return v3Copy(context, zh: '昨日暂无记录', en: 'No data for yesterday',
      tw: '昨日暫無紀錄');
  }
  final previous = trafficForDay(usage, yesterday);
  final change = relativeChangePercent(current: today, previous: previous);
  if (change == null) {
    final total = previous.toStringAsFixed(2);
    return v3Copy(context, zh: '昨日 $total GB',
      en: 'Yesterday $total GB', tw: '昨日 $total GB');
  }
  final rounded = change.abs() < 0.5 ? 0 : change.round();
  final percent = rounded > 0 ? '+$rounded%' : '$rounded%';
  return v3Copy(context, zh: '较昨日 $percent',
    en: 'Vs yesterday $percent', tw: '較昨日 $percent');
}
'''
path.write_text(source, encoding='utf-8')
print('Restored yesterday comparison with V3 locale fallback')

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/traffic_history_series.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3TrafficPage extends StatefulWidget {
  const V3TrafficPage({super.key});
  @override
  State<V3TrafficPage> createState() => _V3TrafficPageState();
}

class _V3TrafficPageState extends State<V3TrafficPage> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    if (!controller.hasPlan && controller.hasAccountSummary) {
      return Center(child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(30), border: Border.all(color: p.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.data_usage_rounded, color: p.lychee, size: 34),
          const SizedBox(height: 16),
          Text('还没有可统计的套餐',
            style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('激活套餐后，这里会显示每天的流量趋势、重置时间与剩余额度。',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: () => controller.goToPage(AppPage.shop),
            icon: const Icon(Icons.storefront_rounded), label: const Text('去选择套餐')),
        ]),
      ));
    }

    final series = TrafficHistorySeries.build(windowDays: _days,
      trafficUsage: controller.trafficUsage, dailyUsage: controller.dailyUsage);
    final traffic = controller.traffic;
    final usedRatio = traffic.totalGb <= 0 ? 0.0 :
      (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(kicker: '使用概览', title: '流量',
            description: '看清今天用了多少、套餐还剩多少，以及最近的使用节奏。',
            trailing: IconButton(tooltip: '刷新流量',
              onPressed: controller.refreshData,
              icon: const Icon(Icons.refresh_rounded))),
          const SizedBox(height: 24),
          if (compact) ...[
            _QuotaPanel(controller: controller, usedRatio: usedRatio),
            const SizedBox(height: 16),
            _TimingPanel(controller: controller),
          ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 11,
              child: _QuotaPanel(controller: controller, usedRatio: usedRatio)),
            const SizedBox(width: 16),
            Expanded(flex: 9, child: _TimingPanel(controller: controller)),
          ]),
          const SizedBox(height: 16),
          _TrendPanel(series: series, periodDays: _days,
            usagePoints: controller.trafficUsage,
            onPeriodChanged: (days) => setState(() => _days = days)),
        ]),
      );
    });
  }
}

class _QuotaPanel extends StatelessWidget {
  const _QuotaPanel({required this.controller, required this.usedRatio});
  final AppController controller;
  final double usedRatio;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final traffic = controller.traffic;
    return Container(padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: p.hero,
        borderRadius: BorderRadius.circular(30), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('套餐流量', style: TextStyle(color: p.inkMuted,
            fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const Spacer(),
          Text('已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: p.lycheeInk, fontSize: 12,
              fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 18),
        Text('${traffic.remainGb.toStringAsFixed(1)} GB',
          style: TextStyle(color: p.ink, fontSize: 38, height: 1,
            fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 8),
        Text('剩余流量', style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 18),
        ClipRRect(borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: usedRatio, minHeight: 8,
            backgroundColor: p.ink.withValues(alpha: .1),
            valueColor: AlwaysStoppedAnimation<Color>(p.lycheeInk))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _QuotaValue(label: '已使用',
            value: '${traffic.usedGb.toStringAsFixed(1)} GB')),
          Expanded(child: _QuotaValue(label: '总额度',
            value: '${traffic.totalGb.toStringAsFixed(1)} GB', alignEnd: true)),
        ]),
      ]),
    );
  }
}

class _QuotaValue extends StatelessWidget {
  const _QuotaValue({required this.label, required this.value, this.alignEnd = false});
  final String label;
  final String value;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: alignEnd ? CrossAxisAlignment.end :
      CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: p.ink, fontSize: 11,
          fontWeight: FontWeight.w800)),
      ]);
  }
}

class _TimingPanel extends StatelessWidget {
  const _TimingPanel({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final resetDays = _daysUntilReset(controller.resetDay);
    return Container(padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(30), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('使用与有效期', style: TextStyle(color: p.inkMuted,
          fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 20),
        _TimingRow(icon: Icons.today_rounded, label: '今日已用',
          value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB', accent: p.lychee),
        _TimingRow(icon: Icons.event_available_rounded, label: '套餐有效期',
          value: controller.planExpiryLabel, accent: p.aqua),
        _TimingRow(icon: Icons.restart_alt_rounded, label: '流量重置',
          value: controller.resetDay == null ? '未提供' : resetDays == null
            ? '每月 ${controller.resetDay} 日' : '$resetDays 天后', accent: p.success),
        _TimingRow(icon: Icons.devices_rounded, label: '在线设备',
          value: controller.aliveIp == null ? '--' : controller.deviceLimit == null
            ? '${controller.aliveIp}' : '${controller.aliveIp} / ${controller.deviceLimit}',
          accent: p.warning, last: true),
      ]),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.icon, required this.label,
    required this.value, required this.accent, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(padding: EdgeInsets.only(bottom: last ? 0 : 15),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: accent.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accent, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
          style: TextStyle(color: p.inkMuted, fontSize: 10))),
        Text(value, style: TextStyle(color: p.ink, fontSize: 11,
          fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

String _dayLabel(DateTime date) =>
  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Real per-day details, never a fabricated upload/download split.
class _DayDetails {
  const _DayDetails({required this.point, required this.upload,
    required this.download});
  final TrafficHistoryDay point;
  final double? upload;
  final double? download;

  factory _DayDetails.forDate(TrafficHistoryDay point, List<TrafficUsagePoint> usage) {
    final matches = usage.where((p) => p.date.year == point.date.year &&
      p.date.month == point.date.month && p.date.day == point.date.day).toList();
    // The data model defaults omitted direction fields to 0. Do not present
    // those defaults as measurements when no real directional data exists.
    final hasDirectionalData = matches.any(
      (p) => p.uploadGb > 0 || p.downloadGb > 0);
    return _DayDetails(point: point,
      upload: hasDirectionalData
        ? matches.fold<double>(0, (sum, p) => sum + p.uploadGb) : null,
      download: hasDirectionalData
        ? matches.fold<double>(0, (sum, p) => sum + p.downloadGb) : null);
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.series, required this.periodDays,
    required this.usagePoints, required this.onPeriodChanged});
  final TrafficHistorySeries series;
  final int periodDays;
  final List<TrafficUsagePoint> usagePoints;
  final ValueChanged<int> onPeriodChanged;

  Future<void> _showDay(BuildContext context, TrafficHistoryDay point) async {
    final details = _DayDetails.forDate(point, usagePoints);
    await showDialog<void>(context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: V3Palette.of(ctx).surface,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('流量详情 · ${_dayLabel(point.date)}',
                    style: Theme.of(ctx).textTheme.titleLarge)),
                  IconButton(tooltip: '关闭',
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: 18),
                Text(point.gb == null ? '该日暂无记录' :
                  '该日总流量 ${point.gb!.toStringAsFixed(2)} GB',
                  style: TextStyle(color: V3Palette.of(ctx).ink,
                    fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (details.upload != null && details.download != null) ...[
                  Text('上传 ${details.upload!.toStringAsFixed(2)} GB'),
                  const SizedBox(height: 6),
                  Text('下载 ${details.download!.toStringAsFixed(2)} GB'),
                ] else Text('后台未提供上传、下载明细',
                  style: TextStyle(color: V3Palette.of(ctx).inkMuted)),
              ]),
          ),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final first = series.days.first.date;
    final last = series.days.last.date;
    return Container(width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(28), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('USAGE TREND', style: TextStyle(color: p.inkMuted,
                fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('$periodDays 天共使用 ${series.totalGb.toStringAsFixed(2)} GB',
                style: TextStyle(color: p.ink, fontSize: 13,
                  fontWeight: FontWeight.w800)),
            ])),
          SegmentedButton<int>(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? p.lycheeSoft : p.surfaceRaised),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected) ? p.lycheeInk : p.ink),
              side: WidgetStateProperty.resolveWith((states) => BorderSide(
                color: states.contains(WidgetState.selected) ? p.lycheeInk : p.line,
                width: states.contains(WidgetState.selected) ? 1.5 : 1)),
              textStyle: const WidgetStatePropertyAll(TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800))),
            segments: const [
              ButtonSegment(value: 7, label: Text('7天')),
              ButtonSegment(value: 30, label: Text('30天')),
            ],
            selected: {periodDays}, showSelectedIcon: true,
            onSelectionChanged: (values) => onPeriodChanged(values.first)),
        ]),
        const SizedBox(height: 8),
        Text('${_dayLabel(first)} 至 ${_dayLabel(last)} · '
          '${series.recordedDays}/$periodDays 天有记录',
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
        if (series.hasGaps) ...[
          const SizedBox(height: 5),
          Text('灰色空位表示该日暂无记录，不代表流量为 0。',
            style: TextStyle(color: p.warningInk, fontSize: 10)),
        ],
        const SizedBox(height: 10),
        Text('悬停查看用量，点击柱形或日期查看真实明细',
          style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 8),
        SizedBox(height: 180,
          child: series.recordedDays == 0
            ? Center(child: Text('暂时没有每日流量记录',
                style: TextStyle(color: p.inkMuted, fontSize: 11)))
            : LayoutBuilder(builder: (context, constraints) {
                // Give every day a real touch target on narrow 7/30-day views.
                final spacing = periodDays == 7 ? 12.0 : 3.0;
                final minChartWidth = periodDays * 44.0 +
                  (periodDays - 1) * spacing;
                final width = constraints.maxWidth > minChartWidth
                  ? constraints.maxWidth : minChartWidth;
                return SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: SizedBox(width: width,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < series.days.length; i++) ...[
                          Expanded(child: _UsageBar(
                            point: series.days[i], maxGb: series.maxGb,
                            compact: periodDays != 7,
                            showLabel: periodDays == 7 || i % 5 == 0 ||
                              i == series.days.length - 1,
                            onTap: () => _showDay(context, series.days[i]))),
                          if (i != series.days.length - 1)
                            SizedBox(width: spacing),
                        ],
                      ]),
                  ),
                );
              }),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _TrendMetric(label: '日均',
            value: series.recordedDays == 0 ? '--' :
              '${series.averageGb.toStringAsFixed(2)} GB')),
          Expanded(child: _TrendMetric(label: '今日',
            value: series.days.last.gb == null ? '--' :
              '${series.days.last.gb!.toStringAsFixed(2)} GB')),
          Expanded(child: _TrendMetric(label: '峰值', alignEnd: true,
            value: series.recordedDays == 0 ? '--' :
              '${series.maxGb.toStringAsFixed(2)} GB')),
        ]),
      ]),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.point, required this.maxGb,
    required this.showLabel, required this.compact, required this.onTap});
  final TrafficHistoryDay point;
  final double maxGb;
  final bool showLabel;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final gb = point.gb;
    final ratio = gb == null || maxGb <= 0 ? 0.0 :
      (gb / maxGb).clamp(0.0, 1.0).toDouble();
    final label = compact ? '${point.date.day}' :
      '${point.date.month}/${point.date.day}';
    final value = gb == null ? '暂无记录' : '${gb.toStringAsFixed(2)} GB';
    return Tooltip(
      message: '${_dayLabel(point.date)} · $value',
      child: Semantics(button: true,
        label: '${_dayLabel(point.date)}，$value，点击查看详情',
        child: InkWell(
          key: ValueKey('v3-traffic-day-${_dayLabel(point.date)}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(height: 168, width: double.infinity,
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(width: double.infinity,
                height: gb == null ? 4 : 18 + 110 * ratio,
                constraints: const BoxConstraints(maxWidth: 34),
                decoration: BoxDecoration(
                  color: gb == null ? p.line : ratio >= .75
                    ? p.lychee : p.aqua.withValues(alpha: .78),
                  borderRadius: BorderRadius.circular(gb == null ? 2 : 8))),
              const SizedBox(height: 8),
              SizedBox(height: 16,
                child: showLabel ? Text(label, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted,
                    fontSize: compact ? 9 : 10)) : null),
            ])),
        ),
      ),
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({required this.label, required this.value,
    this.alignEnd = false});
  final String label;
  final String value;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: alignEnd ? CrossAxisAlignment.end :
      CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: p.ink, fontSize: 12,
          fontWeight: FontWeight.w800)),
      ]);
  }
}

int? _daysUntilReset(int? resetDay) {
  if (resetDay == null || resetDay < 1 || resetDay > 31) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime targetFor(int year, int month) {
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) :
      DateTime(year, month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1)).day;
    return DateTime(year, month, resetDay > lastDay ? lastDay : resetDay);
  }
  var target = targetFor(today.year, today.month);
  if (target.isBefore(today)) {
    final next = DateTime(today.year, today.month + 1, 1);
    target = targetFor(next.year, next.month);
  }
  return target.difference(today).inDays;
}
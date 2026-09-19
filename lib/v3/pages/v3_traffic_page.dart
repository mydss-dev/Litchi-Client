import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/traffic_history_series.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';

/// Supported chart periods are the same on desktop and mobile.
const List<int> kV3TrafficPeriods = [7, 15, 30];

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
        margin: const EdgeInsets.all(V3Layout.pageGutter),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.data_usage_rounded, color: p.lychee, size: 34),
          const SizedBox(height: 12),
          Text(v3Copy(context, zh: '还没有可统计的套餐',
            en: 'No plan with usage data', tw: '尚無可統計的方案'),
            style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => controller.goToPage(AppPage.shop),
            icon: const Icon(Icons.storefront_rounded),
            label: Text(v3Copy(context, zh: '去选择套餐',
              en: 'Choose a plan', tw: '前往選擇方案'))),
        ]),
      ));
    }

    final series = TrafficHistorySeries.build(windowDays: _days,
      trafficUsage: controller.trafficUsage, dailyUsage: controller.dailyUsage);
    final traffic = controller.traffic;
    final usedRatio = traffic.totalGb <= 0 ? 0.0 :
      (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (context, constraints) {
      final compact = !V3Layout.canSplit(
        paneWidth: constraints.maxWidth, primaryMin: 340, secondaryMin: 270);
      return SingleChildScrollView(
        padding: V3Layout.pageInsets,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          V3PageHeader(
            kicker: v3Copy(context, zh: '使用概览', en: 'USAGE OVERVIEW',
              tw: '使用概覽'),
            title: v3Copy(context, zh: '流量', en: 'Traffic', tw: '流量'),
            trailing: IconButton(
              tooltip: v3Copy(context, zh: '刷新流量',
                en: 'Refresh traffic', tw: '重新整理流量'),
              onPressed: controller.refreshData,
              icon: const Icon(Icons.refresh_rounded))),
          const SizedBox(height: 18),
          if (compact) ...[
            _QuotaPanel(controller: controller, usedRatio: usedRatio),
            const SizedBox(height: 12),
            _TimingPanel(controller: controller),
          ] else Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 11,
              child: _QuotaPanel(controller: controller, usedRatio: usedRatio)),
            const SizedBox(width: 12),
            Expanded(flex: 9, child: _TimingPanel(controller: controller)),
          ]),
          const SizedBox(height: 12),
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
    return V3WorkspaceCard(padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(v3Copy(context,
            zh: '套餐流量', en: 'PLAN DATA', tw: '方案流量'),
            style: TextStyle(color: p.inkMuted, fontSize: 11,
              fontWeight: FontWeight.w800))),
          Text(v3Copy(context,
            zh: '已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
            en: '${(usedRatio * 100).toStringAsFixed(0)}% used',
            tw: '已用 ${(usedRatio * 100).toStringAsFixed(0)}%'),
            style: TextStyle(color: p.lycheeInk, fontSize: 11,
              fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Text('${traffic.remainGb.toStringAsFixed(1)} GB',
          style: TextStyle(color: p.ink, fontSize: 33, height: 1,
            fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 5),
        Text(v3Copy(context, zh: '剩余流量', en: 'Remaining data',
          tw: '剩餘流量'), style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: usedRatio, minHeight: 7,
            backgroundColor: p.ink.withValues(alpha: .1),
            valueColor: AlwaysStoppedAnimation<Color>(p.lycheeInk))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _QuotaValue(label: v3Copy(context,
              zh: '已使用', en: 'Used', tw: '已使用'),
            value: '${traffic.usedGb.toStringAsFixed(1)} GB')),
          Expanded(child: _QuotaValue(label: v3Copy(context,
              zh: '总额度', en: 'Total quota', tw: '總額度'),
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
    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v3Copy(context, zh: '使用与有效期',
          en: 'USAGE & EXPIRY', tw: '使用與有效期'),
          style: TextStyle(color: p.inkMuted, fontSize: 11,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _TimingRow(icon: Icons.today_rounded,
          label: v3Copy(context, zh: '今日已用', en: 'Used today', tw: '今日已用'),
          value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB',
          accent: p.lychee),
        _TimingRow(icon: Icons.event_available_rounded,
          label: v3Copy(context, zh: '套餐有效期',
            en: 'Plan expires', tw: '方案有效期'),
          value: controller.planExpiryLabel, accent: p.aqua),
        _TimingRow(icon: Icons.restart_alt_rounded,
          label: v3Copy(context, zh: '流量重置', en: 'Data resets', tw: '流量重置'),
          value: controller.resetDay == null
            ? v3Copy(context, zh: '未提供', en: 'Unavailable', tw: '未提供')
            : resetDays == null
              ? v3Copy(context, zh: '每月 ${controller.resetDay} 日',
                  en: 'Day ${controller.resetDay} monthly',
                  tw: '每月 ${controller.resetDay} 日')
              : v3Copy(context, zh: '$resetDays 天后',
                  en: 'In $resetDays days', tw: '$resetDays 天後'),
          accent: p.success),
        _TimingRow(icon: Icons.devices_rounded,
          label: v3Copy(context, zh: '在线设备',
            en: 'Online devices', tw: '線上裝置'),
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
    return Padding(padding: EdgeInsets.only(bottom: last ? 0 : 11),
      child: Row(children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(color: accent.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: accent, size: 16)),
        const SizedBox(width: 9),
        Expanded(child: Text(label,
          style: TextStyle(color: p.inkMuted, fontSize: 10))),
        Flexible(child: Text(value, maxLines: 2,
          overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
          style: TextStyle(color: p.ink, fontSize: 11,
            fontWeight: FontWeight.w800))),
      ]),
    );
  }
}

String _dayLabel(DateTime date) =>
  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Details are shown only when the server supplied directional records.
class _DayDetails {
  const _DayDetails({required this.upload, required this.download});
  final double? upload;
  final double? download;

  factory _DayDetails.forDate(TrafficHistoryDay point, List<TrafficUsagePoint> usage) {
    final matches = usage.where((p) => p.date.year == point.date.year &&
      p.date.month == point.date.month && p.date.day == point.date.day).toList();
    final hasDirectionalData = matches.any(
      (p) => p.uploadGb > 0 || p.downloadGb > 0);
    return _DayDetails(
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

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v3Copy(context, zh: '流量趋势', en: 'Usage trend', tw: '流量趨勢'),
                style: TextStyle(color: p.inkMuted, fontSize: 11,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(v3Copy(context,
                zh: '近 $periodDays 天 · ${series.totalGb.toStringAsFixed(2)} GB',
                en: '$periodDays days · ${series.totalGb.toStringAsFixed(2)} GB',
                tw: '近 $periodDays 天 · ${series.totalGb.toStringAsFixed(2)} GB'),
                style: TextStyle(color: p.ink, fontSize: 14,
                  fontWeight: FontWeight.w800)),
            ]),
            SegmentedButton<int>(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? p.lycheeSoft : p.surfaceRaised),
                foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected) ? p.lycheeInk : p.ink),
                textStyle: const WidgetStatePropertyAll(TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800)),
                side: WidgetStateProperty.resolveWith((states) => BorderSide(
                  color: states.contains(WidgetState.selected)
                    ? p.lychee : p.line))),
              segments: [for (final days in kV3TrafficPeriods)
                ButtonSegment(value: days, label: Text(v3Copy(context,
                  zh: '$days天', en: '$days days', tw: '$days天')))],
              selected: {periodDays}, showSelectedIcon: false,
              onSelectionChanged: (values) => onPeriodChanged(values.first)),
          ]),
        const SizedBox(height: 16),
        SizedBox(height: 156,
          child: series.recordedDays == 0
            ? Center(child: Text(v3Copy(context,
                zh: '暂时没有每日流量记录', en: 'No daily usage records yet',
                tw: '暫時沒有每日流量紀錄'),
                style: TextStyle(color: p.inkMuted, fontSize: 11)))
            : LayoutBuilder(builder: (context, constraints) {
                final spacing = periodDays == 7 ? 10.0 : 4.0;
                final minChartWidth = periodDays * (periodDays == 7 ? 42.0 : 28.0) +
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
                            details: _DayDetails.forDate(series.days[i], usagePoints),
                            compact: periodDays != 7,
                            showLabel: periodDays == 7 ||
                              i % (periodDays == 15 ? 3 : 5) == 0 ||
                              i == series.days.length - 1)),
                          if (i != series.days.length - 1)
                            SizedBox(width: spacing),
                        ],
                      ]),
                  ),
                );
              }),
        ),
        if (series.hasGaps && series.recordedDays != 0) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(color: p.line,
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(v3Copy(context, zh: '灰色表示暂无记录',
              en: 'Gray: no record', tw: '灰色表示暫無紀錄'),
              style: TextStyle(color: p.inkMuted, fontSize: 10)),
          ]),
        ],
      ]),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.point, required this.maxGb,
    required this.showLabel, required this.compact, required this.details});
  final TrafficHistoryDay point;
  final double maxGb;
  final bool showLabel;
  final bool compact;
  final _DayDetails details;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final gb = point.gb;
    final ratio = gb == null || maxGb <= 0 ? 0.0 :
      (gb / maxGb).clamp(0.0, 1.0).toDouble();
    final label = compact ? '${point.date.day}' :
      '${point.date.month}/${point.date.day}';
    final value = gb == null
      ? v3Copy(context, zh: '暂无记录', en: 'No record', tw: '暫無紀錄')
      : '${gb.toStringAsFixed(2)} GB';
    final detailsText = details.upload == null || details.download == null
      ? '' : v3Copy(context,
          zh: '\n上传 ${details.upload!.toStringAsFixed(2)} GB · 下载 ${details.download!.toStringAsFixed(2)} GB',
          en: '\nUpload ${details.upload!.toStringAsFixed(2)} GB · Download ${details.download!.toStringAsFixed(2)} GB',
          tw: '\n上傳 ${details.upload!.toStringAsFixed(2)} GB · 下載 ${details.download!.toStringAsFixed(2)} GB');
    return Tooltip(
      message: '${_dayLabel(point.date)}\n$value$detailsText',
      child: Semantics(label: '${_dayLabel(point.date)}，$value',
        child: SizedBox(height: 140, width: double.infinity,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(width: double.infinity,
              height: gb == null ? 4 : 8 + 92 * ratio,
              constraints: BoxConstraints(maxWidth: compact ? 22 : 34),
              decoration: BoxDecoration(
                color: gb == null ? p.line : ratio >= .75
                  ? p.lychee : p.aqua.withValues(alpha: .78),
                borderRadius: BorderRadius.circular(gb == null ? 2 : 6))),
            const SizedBox(height: 8),
            SizedBox(height: 16,
              child: showLabel ? Text(label, maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.inkMuted,
                  fontSize: compact ? 9 : 10)) : null),
          ])),
      ),
    );
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

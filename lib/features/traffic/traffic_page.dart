import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/app_select.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';

/// Statistics page (§13): compact traffic, device, and subscription stats.
class TrafficPage extends StatefulWidget {
  const TrafficPage({super.key});

  @override
  State<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends State<TrafficPage> {
  String _period = '最近7天';

  Future<void> _refresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  Future<void> _handleRefresh() => _refresh();

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: '流量统计',
      subtitle: '查看流量、设备和套餐周期',
      compactTitle: '流量',
      primaryCompact: isPrimaryCompactTab(AppPage.traffic),
      onRefresh: _handleRefresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      children: _bodyChildren(context),
    );
  }

  // ── Shared body ────────────────────────────────────────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    return [
      const _StatsGrid(),
      const SizedBox(height: 16),
      _UsageTrendCard(
        period: _period,
        onPeriodChanged: (v) => setState(() => _period = v),
      ),
    ];
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1040
            ? 4
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        const gap = 16.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: cardWidth, child: const _TrafficCard()),
            SizedBox(width: cardWidth, child: const _RemainingDaysCard()),
            SizedBox(width: cardWidth, child: const _DevicesCard()),
            SizedBox(width: cardWidth, child: const _TrafficResetCard()),
          ],
        );
      },
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard();

  @override
  Widget build(BuildContext context) {
    final traffic = AppScope.of(context).traffic;
    final ratio = traffic.totalGb > 0
        ? (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0)
        : 0.0;

    return _StatCard(
      icon: LucideIcons.chartPie,
      title: '流量统计',
      value: '${traffic.usedGb.toStringAsFixed(0)} GB',
      unit: '/ ${traffic.totalGb.toStringAsFixed(0)} GB',
      footer: '剩余 ${traffic.remainGb.toStringAsFixed(0)} GB',
      progress: ratio,
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final deviceCount = ctrl.aliveIp ?? 0;
    final deviceLimit = ctrl.deviceLimit;
    final hasLimit = deviceLimit != null && deviceLimit > 0;

    return _StatCard(
      icon: LucideIcons.monitorSmartphone,
      title: '在线设备',
      value: '$deviceCount',
      unit: '/ ${hasLimit ? deviceLimit : '∞'}',
      footer: '当前在线设备数',
      progress: hasLimit ? (deviceCount / deviceLimit).clamp(0.0, 1.0) : null,
    );
  }
}

class _RemainingDaysCard extends StatelessWidget {
  const _RemainingDaysCard();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final expiredAt = ctrl.expiredAt;
    final expiry = expiredAt == null || expiredAt == 0
        ? ctrl.user.expiry
        : formatDate(DateTime.fromMillisecondsSinceEpoch(expiredAt * 1000));
    final remainingDays = expiredAt == null || expiredAt == 0
        ? _remainingDays(expiry)
        : _remainingDaysFromTimestamp(expiredAt);

    return _StatCard(
      icon: LucideIcons.calendarDays,
      title: '剩余日期',
      value: remainingDays == null ? '永久' : '$remainingDays',
      unit: remainingDays == null ? '' : '天',
      footer: remainingDays == null ? '订阅长期有效' : '到期 $expiry',
      progress: null,
    );
  }

  int? _remainingDays(String expiry) {
    final expiryDate = DateTime.tryParse(expiry);
    if (expiryDate == null) return null;
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return end.difference(start).inDays.clamp(0, 9999);
  }

  int _remainingDaysFromTimestamp(int timestamp) {
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return end.difference(start).inDays.clamp(0, 9999);
  }
}

class _TrafficResetCard extends StatelessWidget {
  const _TrafficResetCard();

  @override
  Widget build(BuildContext context) {
    final resetDay = AppScope.of(context).resetDay;
    return _StatCard(
      icon: LucideIcons.refreshCw,
      title: '流量重置时间',
      value: resetDay == null ? '不重置' : '$resetDay 天',
      footer: resetDay == null ? '当前套餐未配置重置周期' : '距下次重置',
      progress: null,
    );
  }
}

class _UsageTrendCard extends StatefulWidget {
  const _UsageTrendCard({required this.period, required this.onPeriodChanged});

  final String period;
  final ValueChanged<String> onPeriodChanged;

  @override
  State<_UsageTrendCard> createState() => _UsageTrendCardState();
}

class _UsageTrendCardState extends State<_UsageTrendCard> {
  final _scrollController = ScrollController();
  String? _scrollKey;

  String get period => widget.period;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final data = _chartData(ctrl.trafficUsage, ctrl.dailyUsage);
    final maxV = data.isEmpty
        ? 10.0
        : data.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final maxY = _niceMaxY(maxV);
    final axisUnit = maxY < 1 ? _TrafficAxisUnit.mb : _TrafficAxisUnit.gb;
    final total = data.fold<double>(0, (sum, p) => sum + p.value);
    final days = _daysForPeriod();
    final slotWidth = days <= 7 ? 54.0 : 36.0;
    final barWidth = days <= 7 ? 18.0 : 16.0;
    _scrollToLatestAfterLayout(data);

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.activity, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '流量趋势图',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$period 共 ${formatGb(total)}',
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppSelect<String>(
                value: period,
                items: const ['最近7天', '最近30天', '最近90天'],
                labelOf: (v) => v,
                onChanged: widget.onPeriodChanged,
                minWidth: 104,
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = data.length * slotWidth;
              const axisWidth = 58.0;
              final scrollWidth = (constraints.maxWidth - axisWidth).clamp(
                120.0,
                double.infinity,
              );
              final chartWidth = minWidth > scrollWidth
                  ? minWidth
                  : scrollWidth;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: axisWidth,
                    height: 226,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _axisLabel(maxY, axisUnit),
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _axisLabel(0, axisUnit),
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      thickness: 6,
                      radius: const Radius.circular(999),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          height: 226,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 170,
                                  child: BarChart(
                                    BarChartData(
                                      maxY: maxY,
                                      barTouchData: BarTouchData(
                                        touchTooltipData: BarTouchTooltipData(
                                          fitInsideHorizontally: true,
                                          fitInsideVertically: true,
                                          maxContentWidth: 160,
                                          getTooltipColor: (_) => c.textPrimary,
                                          getTooltipItem:
                                              (
                                                group,
                                                groupIndex,
                                                rod,
                                                rodIndex,
                                              ) {
                                                final point =
                                                    data[group.x.toInt()];
                                                return BarTooltipItem(
                                                  '${point.tooltipLabel}\n上行 ${formatGb(point.uploadGb)}\n下行 ${formatGb(point.downloadGb)}\n合计 ${formatGb(point.value)}',
                                                  AppTextStyles.caption
                                                      .copyWith(
                                                        color: c.cardBg,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                );
                                              },
                                        ),
                                      ),
                                      alignment: BarChartAlignment.spaceAround,
                                      borderData: FlBorderData(show: false),
                                      gridData: FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                        horizontalInterval: _gridInterval(maxY),
                                        getDrawingHorizontalLine: (_) => FlLine(
                                          color: c.softBorder,
                                          strokeWidth: 1,
                                        ),
                                      ),
                                      titlesData: const FlTitlesData(
                                        topTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                      ),
                                      barGroups: [
                                        for (int i = 0; i < data.length; i++)
                                          BarChartGroupData(
                                            x: i,
                                            barRods: [
                                              BarChartRodData(
                                                toY: data[i].value,
                                                width: barWidth,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                                gradient: LinearGradient(
                                                  begin: Alignment.bottomCenter,
                                                  end: Alignment.topCenter,
                                                  colors: [
                                                    AppPalette.brandStart,
                                                    AppPalette.brandEnd,
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    duration: Duration.zero,
                                  ),
                                ),
                                Container(height: 1, color: c.softBorder),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    for (final point in data)
                                      SizedBox(
                                        width: slotWidth,
                                        child: Text(
                                          point.label,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          style: AppTextStyles.caption.copyWith(
                                            color: c.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<_ChartPoint> _chartData(
    List<TrafficUsagePoint> usage,
    List<double> fallback,
  ) {
    final days = _daysForPeriod();
    if (usage.isEmpty) {
      final raw = fallback.skip(
        (fallback.length - days).clamp(0, fallback.length),
      );
      return raw
          .toList()
          .asMap()
          .entries
          .map((e) => _ChartPoint(label: _fallbackLabel(e.key), value: e.value))
          .toList();
    }

    final points = _lastCalendarDays(usage, days);
    return [
      for (int i = 0; i < points.length; i++)
        _ChartPoint(
          label: _monthDay(points[i].date),
          tooltipLabel:
              '${_monthDay(points[i].date)} ${_weekdayLabel(points[i].date.weekday)}',
          value: points[i].totalGb,
          uploadGb: points[i].uploadGb,
          downloadGb: points[i].downloadGb,
        ),
    ];
  }

  List<TrafficUsagePoint> _lastCalendarDays(
    List<TrafficUsagePoint> usage,
    int count,
  ) {
    if (usage.isEmpty) return const [];
    final byDate = {
      for (final p in usage) DateTime(p.date.year, p.date.month, p.date.day): p,
    };
    final endRaw = usage.last.date;
    final end = DateTime(endRaw.year, endRaw.month, endRaw.day);
    return [
      for (int i = count - 1; i >= 0; i--)
        () {
          final date = end.subtract(Duration(days: i));
          return byDate[date] ?? TrafficUsagePoint(date: date, totalGb: 0);
        }(),
    ];
  }

  String _monthDay(DateTime date) => '${date.month}/${date.day}';

  String _weekdayLabel(int weekday) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    if (weekday < 1 || weekday > labels.length) return '';
    return labels[weekday - 1];
  }

  String _fallbackLabel(int index) => '${index + 1}';

  int _daysForPeriod() => switch (period) {
    '最近30天' => 30,
    '最近90天' => 90,
    _ => 7,
  };

  double _niceMaxY(double value) {
    if (value <= 0.05) return 0.05;
    if (value <= 0.1) return 0.1;
    if (value <= 0.5) return 0.5;
    if (value <= 1) return 1;
    if (value <= 5) return value.ceilToDouble();
    return ((value / 10).ceil() * 10).toDouble();
  }

  double _gridInterval(double maxY) {
    if (maxY <= 0.1) return 0.05;
    if (maxY <= 0.5) return 0.1;
    if (maxY <= 1) return 0.25;
    if (maxY <= 5) return 1;
    return maxY / 5;
  }

  String _axisLabel(double value, _TrafficAxisUnit unit) {
    if (unit == _TrafficAxisUnit.mb) {
      final mb = value * 1024;
      if (mb == 0) return '0 MB';
      if (mb < 10) return '${mb.toStringAsFixed(1)} MB';
      return '${mb.round()} MB';
    }
    if (value == 0) return '0 GB';
    if (value == value.roundToDouble()) return '${value.toInt()} GB';
    return '${value.toStringAsFixed(1)} GB';
  }

  void _scrollToLatestAfterLayout(List<_ChartPoint> data) {
    final key = '$period:${data.length}:${data.isEmpty ? '' : data.last.label}';
    if (_scrollKey == key) return;
    _scrollKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
}

class _ChartPoint {
  const _ChartPoint({
    required this.label,
    required this.value,
    String? tooltipLabel,
    this.uploadGb = 0,
    this.downloadGb = 0,
  }) : tooltipLabel = tooltipLabel ?? label;

  final String label;
  final double value;
  final String tooltipLabel;
  final double uploadGb;
  final double downloadGb;
}

enum _TrafficAxisUnit { mb, gb }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.footer,
    this.unit = '',
    this.progress,
  });

  final IconData icon;
  final String title;
  final String value;
  final String unit;
  final String footer;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 138,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.sectionTitle.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.largeNumber(
                      fontSize: 30,
                    ).copyWith(color: c.textPrimary),
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            if (progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Stack(
                  children: [
                    Container(height: 8, color: c.surfaceMuted),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: progress! >= 1 ? c.danger : c.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              footer,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

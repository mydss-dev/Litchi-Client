import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_palette.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_select.dart';

class GreenfieldTrafficSurface extends StatelessWidget {
  const GreenfieldTrafficSurface({
    super.key,
    required this.traffic,
    required this.todayTrafficGb,
    required this.todayComparison,
    required this.expiryDays,
    required this.expiryDate,
    required this.resetDay,
    required this.resetDays,
    required this.usage,
    required this.fallbackDailyUsage,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  final TrafficModel traffic;
  final double todayTrafficGb;
  final String todayComparison;
  final int? expiryDays;
  final String expiryDate;
  final int? resetDay;
  final int? resetDays;
  final List<TrafficUsagePoint> usage;
  final List<double> fallbackDailyUsage;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final touch = AppPlatform.usesTouch;
    final usedRatio = traffic.totalGb > 0
        ? (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      key: const ValueKey('greenfield-traffic-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QuotaHero(
          touch: touch,
          remaining: formatGb(traffic.remainGb),
          used: formatGb(traffic.usedGb),
          total: formatGb(traffic.totalGb),
          usedRatio: usedRatio,
          today: formatGb(todayTrafficGb),
          todayComparison: todayComparison,
        ),
        const SizedBox(height: AppSpacing.lg),
        _CycleStatusRow(
          expiryDays: expiryDays,
          expiryDate: expiryDate,
          resetDay: resetDay,
          resetDays: resetDays,
        ),
        const SizedBox(height: AppSpacing.lg),
        _UsageTrendCard(
          usage: usage,
          fallbackDailyUsage: fallbackDailyUsage,
          periodDays: periodDays,
          onPeriodChanged: onPeriodChanged,
        ),
        if (touch) const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _QuotaHero extends StatelessWidget {
  const _QuotaHero({
    required this.touch,
    required this.remaining,
    required this.used,
    required this.total,
    required this.usedRatio,
    required this.today,
    required this.todayComparison,
  });

  final bool touch;
  final String remaining;
  final String used;
  final String total;
  final double usedRatio;
  final String today;
  final String todayComparison;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: EdgeInsets.all(touch ? AppSpacing.lg : AppSpacing.xl),
      color: c.primarySoft.withValues(alpha: 0.46),
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.soft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackBody = touch || constraints.maxWidth < 560;
          final quota = _QuotaBlock(
            remaining: remaining,
            used: used,
            total: total,
            usedRatio: usedRatio,
          );
          final todayBlock = _TodayBlock(
            value: today,
            comparison: todayComparison,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!touch) ...[
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        LucideIcons.chartPie,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.trafficStatistics,
                            style: AppTextStyles.sectionTitle.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.l10n.trafficStatisticsSubtitle,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (stackBody) ...[
                quota,
                const SizedBox(height: AppSpacing.lg),
                todayBlock,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: quota),
                    const SizedBox(width: AppSpacing.xl),
                    SizedBox(width: 210, child: todayBlock),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuotaBlock extends StatelessWidget {
  const _QuotaBlock({
    required this.remaining,
    required this.used,
    required this.total,
    required this.usedRatio,
  });

  final String remaining;
  final String used;
  final String total;
  final double usedRatio;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.remainingTrafficLabel,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          remaining,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.largeNumber(fontSize: 38).copyWith(
            color: c.textPrimary,
            height: 1.05,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            children: [
              Container(height: 10, color: c.cardBg.withValues(alpha: 0.8)),
              FractionallySizedBox(
                widthFactor: usedRatio,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: usedRatio >= 0.95 ? c.danger : c.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                used,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              context.l10n.totalTrafficLabel(total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _TodayBlock extends StatelessWidget {
  const _TodayBlock({required this.value, required this.comparison});

  final String value;
  final String comparison;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.cardBg.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.chartColumn, size: 17, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.todayUsedLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionTitle.copyWith(
              color: c.textPrimary,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            comparison,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CycleStatusRow extends StatelessWidget {
  const _CycleStatusRow({
    required this.expiryDays,
    required this.expiryDate,
    required this.resetDay,
    required this.resetDays,
  });

  final int? expiryDays;
  final String expiryDate;
  final int? resetDay;
  final int? resetDays;

  @override
  Widget build(BuildContext context) {
    final expiryValue = expiryDays == null
        ? context.l10n.permanent
        : context.l10n.daysCount(expiryDays!);
    final expiryFooter = expiryDays == null || expiryDate.isEmpty
        ? context.l10n.subscriptionLongTerm
        : context.l10n.expiresAt(expiryDate);
    final resetValue = resetDays == null
        ? context.l10n.neverResets
        : context.l10n.daysCount(resetDays!);
    final resetFooter = resetDay == null
        ? context.l10n.noTrafficReset
        : context.l10n.monthlyResetDay(resetDay!);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 520;
        final expiry = _CycleCard(
          icon: LucideIcons.calendarDays,
          label: context.l10n.remainingDaysLabel,
          value: expiryValue,
          footer: expiryFooter,
        );
        final reset = _CycleCard(
          icon: LucideIcons.refreshCw,
          label: context.l10n.resetCountdownLabel,
          value: resetValue,
          footer: resetFooter,
        );
        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              expiry,
              const SizedBox(height: AppSpacing.md),
              reset,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: expiry),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: reset),
          ],
        );
      },
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.footer,
  });

  final IconData icon;
  final String label;
  final String value;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 19, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageTrendCard extends StatefulWidget {
  const _UsageTrendCard({
    required this.usage,
    required this.fallbackDailyUsage,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  final List<TrafficUsagePoint> usage;
  final List<double> fallbackDailyUsage;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  @override
  State<_UsageTrendCard> createState() => _UsageTrendCardState();
}

class _UsageTrendCardState extends State<_UsageTrendCard> {
  final ScrollController _scrollController = ScrollController();
  String? _scrollKey;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final data = _chartData(widget.usage, widget.fallbackDailyUsage);
    final maxV = data.isEmpty
        ? 10.0
        : data.map((point) => point.value).reduce((a, b) => a > b ? a : b);
    final maxY = _niceMaxY(maxV);
    final axisUnit = maxY < 1 ? _TrafficAxisUnit.mb : _TrafficAxisUnit.gb;
    final total = data.fold<double>(0, (sum, point) => sum + point.value);
    final slotWidth = widget.periodDays <= 7 ? 54.0 : 36.0;
    final barWidth = widget.periodDays <= 7 ? 18.0 : 16.0;
    _scrollToLatestAfterLayout(data);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = AppPlatform.usesTouch || constraints.maxWidth < 520;
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.activity, size: 18, color: c.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          context.l10n.trafficTrend,
                          style: AppTextStyles.sectionTitle.copyWith(
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    context.l10n.periodTrafficTotal(
                      context.l10n.recentDays(widget.periodDays),
                      formatGb(total),
                    ),
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              );
              final selector = AppSelect<int>(
                value: widget.periodDays,
                items: const [7, 30, 90],
                labelOf: (value) => context.l10n.recentDays(value),
                onChanged: widget.onPeriodChanged,
                minWidth: 104,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    const SizedBox(height: AppSpacing.md),
                    Align(alignment: Alignment.centerLeft, child: selector),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: title),
                  const SizedBox(width: AppSpacing.md),
                  selector,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data.isEmpty)
            SizedBox(
              height: 190,
              child: Center(
                child: Text(
                  context.l10n.periodTrafficTotal(
                    context.l10n.recentDays(widget.periodDays),
                    formatGb(0),
                  ),
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
            )
          else
            _TrendChart(
              data: data,
              maxY: maxY,
              axisUnit: axisUnit,
              slotWidth: slotWidth,
              barWidth: barWidth,
              scrollController: _scrollController,
            ),
        ],
      ),
    );
  }

  List<_ChartPoint> _chartData(
    List<TrafficUsagePoint> usage,
    List<double> fallback,
  ) {
    final days = widget.periodDays;
    if (usage.isEmpty) {
      final start = (fallback.length - days).clamp(0, fallback.length);
      return fallback
          .skip(start)
          .toList()
          .asMap()
          .entries
          .map(
            (entry) => _ChartPoint(
              label: '${entry.key + 1}',
              value: entry.value,
            ),
          )
          .toList();
    }

    final points = _lastCalendarDays(usage, days);
    return [
      for (final point in points)
        _ChartPoint(
          label: '${point.date.month}/${point.date.day}',
          tooltipLabel:
              '${point.date.month}/${point.date.day} ${_weekdayLabel(point.date.weekday)}',
          value: point.totalGb,
          uploadGb: point.uploadGb,
          downloadGb: point.downloadGb,
        ),
    ];
  }

  List<TrafficUsagePoint> _lastCalendarDays(
    List<TrafficUsagePoint> usage,
    int count,
  ) {
    if (usage.isEmpty) return const [];
    final byDate = {
      for (final point in usage)
        DateTime(point.date.year, point.date.month, point.date.day): point,
    };
    final endRaw = usage.last.date;
    final end = DateTime(endRaw.year, endRaw.month, endRaw.day);
    return [
      for (int offset = count - 1; offset >= 0; offset--)
        () {
          final date = end.subtract(Duration(days: offset));
          return byDate[date] ?? TrafficUsagePoint(date: date, totalGb: 0);
        }(),
    ];
  }

  String _weekdayLabel(int weekday) {
    final labels = context.l10n.weekdayShort.split(',');
    if (weekday < 1 || weekday > labels.length) return '';
    return labels[weekday - 1];
  }

  double _niceMaxY(double value) {
    if (value <= 0.05) return 0.05;
    if (value <= 0.1) return 0.1;
    if (value <= 0.5) return 0.5;
    if (value <= 1) return 1;
    if (value <= 5) return value.ceilToDouble();
    return ((value / 10).ceil() * 10).toDouble();
  }

  void _scrollToLatestAfterLayout(List<_ChartPoint> data) {
    final key =
        '${widget.periodDays}:${data.length}:${data.isEmpty ? '' : data.last.label}';
    if (_scrollKey == key) return;
    _scrollKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.data,
    required this.maxY,
    required this.axisUnit,
    required this.slotWidth,
    required this.barWidth,
    required this.scrollController,
  });

  final List<_ChartPoint> data;
  final double maxY;
  final _TrafficAxisUnit axisUnit;
  final double slotWidth;
  final double barWidth;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const axisWidth = 58.0;
        final minWidth = data.length * slotWidth;
        final scrollWidth = (constraints.maxWidth - axisWidth).clamp(
          120.0,
          double.infinity,
        );
        final chartWidth = minWidth > scrollWidth ? minWidth : scrollWidth;
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
                controller: scrollController,
                thumbVisibility: true,
                trackVisibility: !AppPlatform.usesTouch,
                interactive: true,
                thickness: 6,
                radius: const Radius.circular(AppRadius.pill),
                child: SingleChildScrollView(
                  controller: scrollController,
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
                                        (group, groupIndex, rod, rodIndex) {
                                      final point = data[group.x.toInt()];
                                      return BarTooltipItem(
                                        '${point.tooltipLabel}\n'
                                        '${context.l10n.tooltipUpload(formatGb(point.uploadGb))}\n'
                                        '${context.l10n.tooltipDownload(formatGb(point.downloadGb))}\n'
                                        '${context.l10n.tooltipTotal(formatGb(point.value))}',
                                        AppTextStyles.caption.copyWith(
                                          color: c.cardBg,
                                          fontWeight: FontWeight.w700,
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
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                barGroups: [
                                  for (int index = 0; index < data.length; index++)
                                    BarChartGroupData(
                                      x: index,
                                      barRods: [
                                        BarChartRodData(
                                          toY: data[index].value,
                                          width: barWidth,
                                          borderRadius: BorderRadius.circular(5),
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
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    );
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

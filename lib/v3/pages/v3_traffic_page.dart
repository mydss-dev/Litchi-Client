import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/utils/traffic_summary_text.dart';
import '../../shared/utils/traffic_metrics.dart';
import '../../shared/services/traffic_history_series.dart';
import '../theme/v3_motion.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_layout.dart';
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
  final ScrollController _trendScroll = ScrollController();
  String? _lastTrendKey;

  @override
  void dispose() {
    _trendScroll.dispose();
    super.dispose();
  }

  void _scrollToLatest(TrafficHistorySeries series) {
    if (series.days.isEmpty) return;
    final day = series.days.last.date;
    final key =
        '$_days:${series.days.length}:${day.year}-${day.month}-${day.day}';
    if (_lastTrendKey == key) return;
    _lastTrendKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _trendScroll.hasClients) {
        _trendScroll.jumpTo(_trendScroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    if (controller.hasConfirmedNoPlan && !controller.isInitialLoading) {
      return LayoutBuilder(
        builder: (context, viewport) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: viewport.maxHeight.isFinite ? viewport.maxHeight : 0,
            ),
            child: Center(
              // The shared empty-state voice (icon tile, one muted line, one
              // step out) instead of a private hand-rolled panel.
              child: V3EmptyState(
                icon: Icons.data_usage_rounded,
                title: v3Copy(
                  context,
                  zh: '还没有可统计的套餐',
                  en: 'No plan with usage data',
                  tw: '尚無可統計的方案',
                ),
                subtitle: v3Copy(
                  context,
                  zh: '选择一个套餐开始使用，用量会统计在这里。',
                  en: 'Pick a plan to get started; your usage shows up here.',
                  tw: '選擇一個方案開始使用，用量會統計在這裡。',
                ),
                actionLabel: v3Copy(
                  context,
                  zh: '去选择套餐',
                  en: 'Choose a plan',
                  tw: '前往選擇方案',
                ),
                onAction: () => controller.goToPage(AppPage.shop),
              ),
            ),
          ),
        ),
      );
    }

    // Three-state chain, the round-2 standard the nodes and shop pages use:
    // named failure -> block skeleton -> data. Zeros never stand in for a
    // value that has not loaded, and a failed load is never silent.
    if (controller.dataLoadError != null && !controller.hasAccountSummary) {
      // Failure is not emptiness: name the error and offer the retry.
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: V3Layout.pageInsets,
        child: V3WaveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            V3PageHeader(
              title: v3Copy(
                context,
                zh: '流量用量',
                en: 'Traffic usage',
                tw: '流量用量',
              ),
            ),
            V3EmptyState(
              icon: Icons.error_outline_rounded,
              title: v3Copy(
                context,
                zh: '流量加载失败',
                en: 'Could not load traffic',
                tw: '流量載入失敗',
              ),
              subtitle: controller.dataLoadError!,
              actionLabel: v3Copy(context, zh: '重试', en: 'Retry', tw: '重試'),
              onAction: () => controller.refreshData(),
            ),
          ],
        ),
      );
    }
    if (controller.isInitialLoading || !controller.hasAccountSummary) {
      // First load, or a retry still fetching the first data: block
      // placeholders in the page's own shape instead of a 0.0 GB flash.
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: V3Layout.pageInsets,
        child: V3WaveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            V3PageHeader(
              title: v3Copy(
                context,
                zh: '流量用量',
                en: 'Traffic usage',
                tw: '流量用量',
              ),
            ),
            const SizedBox(height: 18),
            const _TrafficSkeleton(),
          ],
        ),
      );
    }

    final series = TrafficHistorySeries.build(
      windowDays: _days,
      trafficUsage: controller.trafficUsage,
      dailyUsage: controller.dailyUsage,
    );
    _scrollToLatest(series);
    final traffic = controller.traffic;
    final usedRatio = traffic.totalGb <= 0
        ? 0.0
        : (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0).toDouble();
    // Full-width summary, then the stat-tile band, then the chart. No
    // side-by-side split — every block owns the whole row.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            title: v3Copy(context, zh: '流量用量', en: 'Traffic usage', tw: '流量用量'),
            trailing: _RefreshIconButton(
              tooltip: v3Copy(
                context,
                zh: '刷新流量',
                en: 'Refresh traffic',
                tw: '重新整理流量',
              ),
              onRefresh: controller.refreshData,
            ),
          ),
          const SizedBox(height: 18),
          if (controller.dataLoadError != null) ...[
            // The refresh failed while data is on screen: this strip keeps the
            // failure visible instead of letting the standing numbers read as
            // fresh (round-3 audit F12; the dashboard warning tile's voice).
            _DataErrorRow(
              message: controller.dataLoadError!,
              onRetry: controller.refreshData,
            ),
            const SizedBox(height: 12),
          ],
          _QuotaPanel(controller: controller, usedRatio: usedRatio),
          const SizedBox(height: 12),
          _TimingGrid(controller: controller),
          const SizedBox(height: 12),
          _TrendPanel(
            series: series,
            periodDays: _days,
            usagePoints: controller.trafficUsage,
            scrollController: _trendScroll,
            onPeriodChanged: (days) => setState(() => _days = days),
          ),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  v3Copy(context, zh: '套餐流量', en: 'PLAN DATA', tw: '方案流量'),
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                v3Copy(
                  context,
                  zh: '已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
                  en: '${(usedRatio * 100).toStringAsFixed(0)}% used',
                  tw: '已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
                ),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${traffic.remainGb.toStringAsFixed(1)} GB',
            style: TextStyle(
              color: p.ink,
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            v3Copy(context, zh: '剩余流量', en: 'Remaining data', tw: '剩餘流量'),
            style: TextStyle(color: p.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(V3Radius.control),
            // The bar sweeps from empty on load and glides between values on
            // refresh instead of jumping to the new fill.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: usedRatio),
              duration: v3ReducedMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, swept, _) => LinearProgressIndicator(
                value: swept,
                minHeight: 7,
                backgroundColor: p.ink.withValues(alpha: .1),
                // Data progress is a measured value: green, never brand pink
                // (the dashboard gauge is the reference standard).
                valueColor: AlwaysStoppedAnimation<Color>(p.success),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuotaValue(
                  label: v3Copy(context, zh: '已使用', en: 'Used', tw: '已使用'),
                  value: '${traffic.usedGb.toStringAsFixed(1)} GB',
                ),
              ),
              Expanded(
                child: _QuotaValue(
                  label: v3Copy(
                    context,
                    zh: '总额度',
                    en: 'Total quota',
                    tw: '總額度',
                  ),
                  value: '${traffic.totalGb.toStringAsFixed(1)} GB',
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaValue extends StatelessWidget {
  const _QuotaValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });
  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: p.inkMuted, fontSize: 11)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: p.ink,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// The stat-tile band, kept as separate cards on the canvas. Wide panes lay
/// it out 3x2, narrow ones 2x3; each tile keeps its accent so the band is
/// the page's color stripe.
class _TimingGrid extends StatelessWidget {
  const _TimingGrid({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final resetDays = _daysUntilReset(controller.resetDay);
    final expiry = subscriptionExpiryDisplay(
      expiredAt: controller.expiredAt,
      expiryText: controller.user.expiry,
    );
    final days = expiry.days;
    final tiles = <Widget>[
      V3StatTile(
        icon: Icons.today_rounded,
        label: v3Copy(context, zh: '今日已用', en: 'Used today', tw: '今日已用'),
        value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB',
        accent: p.lychee,
      ),
      V3StatTile(
        icon: Icons.compare_arrows_rounded,
        label: v3Copy(context, zh: '昨日对比', en: 'Vs. yesterday', tw: '昨日對比'),
        value: _v3YesterdayComparison(
          context,
          controller.trafficUsage,
          controller.todayTrafficGb,
        ),
        accent: p.aquaInk,
      ),
      V3StatTile(
        icon: Icons.event_available_rounded,
        label: v3Copy(context, zh: '套餐有效期', en: 'Plan expires', tw: '方案有效期'),
        value: controller.planExpiryLabel,
        accent: p.aquaInk,
      ),
      if (days != null)
        V3StatTile(
          icon: Icons.hourglass_bottom_rounded,
          label: v3Copy(context, zh: '距离到期', en: 'Time remaining', tw: '距離到期'),
          value: days < 0
              ? v3Copy(context, zh: '已过期', en: 'Expired', tw: '已過期')
              : days == 0
              ? v3Copy(context, zh: '今天到期', en: 'Expires today', tw: '今天到期')
              : v3Copy(context, zh: '$days 天', en: '$days days', tw: '$days 天'),
          accent: days <= 0 ? p.warning : p.aquaInk,
        ),
      V3StatTile(
        icon: Icons.restart_alt_rounded,
        label: v3Copy(context, zh: '流量重置', en: 'Data resets', tw: '流量重置'),
        value: controller.resetDay == null
            ? v3Copy(context, zh: '未提供', en: 'Unavailable', tw: '未提供')
            : resetDays == null
            ? v3Copy(
                context,
                zh: '每月 ${controller.resetDay} 日',
                en: 'Day ${controller.resetDay} monthly',
                tw: '每月 ${controller.resetDay} 日',
              )
            : v3Copy(
                context,
                zh: '$resetDays 天后',
                en: 'In $resetDays days',
                tw: '$resetDays 天後',
              ),
        accent: p.success,
      ),
      V3StatTile(
        icon: Icons.devices_rounded,
        label: v3Copy(context, zh: '在线设备', en: 'Online devices', tw: '線上裝置'),
        value: controller.aliveIp == null
            ? '--'
            : controller.deviceLimit == null
            ? '${controller.aliveIp}'
            : '${controller.aliveIp} / ${controller.deviceLimit}',
        accent: p.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= V3Layout.paneCompact ? 3 : 2;
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += cols) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                children: [
                  for (
                    var j = i;
                    j < (i + cols).clamp(0, tiles.length);
                    j++
                  ) ...[
                    if (j > i) const SizedBox(width: 12),
                    Expanded(child: tiles[j]),
                  ],
                ],
              ),
            ],
          ],
        );
      },
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

  factory _DayDetails.forDate(
    TrafficHistoryDay point,
    List<TrafficUsagePoint> usage,
  ) {
    final matches = usage
        .where(
          (p) =>
              p.date.year == point.date.year &&
              p.date.month == point.date.month &&
              p.date.day == point.date.day,
        )
        .toList();
    final hasDirectionalData = matches.any(
      (p) => p.uploadGb > 0 || p.downloadGb > 0,
    );
    return _DayDetails(
      upload: hasDirectionalData
          ? matches.fold<double>(0, (sum, p) => sum + p.uploadGb)
          : null,
      download: hasDirectionalData
          ? matches.fold<double>(0, (sum, p) => sum + p.downloadGb)
          : null,
    );
  }
}

/// The trend panel. No pinned-day readout: the numbers live on the bar
/// captions (7-day view) and the hover tooltip.
class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.series,
    required this.periodDays,
    required this.usagePoints,
    required this.onPeriodChanged,
    required this.scrollController,
  });
  final TrafficHistorySeries series;
  final int periodDays;
  final List<TrafficUsagePoint> usagePoints;
  final ValueChanged<int> onPeriodChanged;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return _TrendPanelView(
      series: series,
      periodDays: periodDays,
      usagePoints: usagePoints,
      onPeriodChanged: onPeriodChanged,
      scrollController: scrollController,
    );
  }
}

class _TrendPanelView extends StatelessWidget {
  const _TrendPanelView({
    required this.series,
    required this.periodDays,
    required this.usagePoints,
    required this.onPeriodChanged,
    required this.scrollController,
  });
  final TrafficHistorySeries series;
  final int periodDays;
  final List<TrafficUsagePoint> usagePoints;
  final ValueChanged<int> onPeriodChanged;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Controls on their own line: title left, range picker right. The
          // readings get the next line to themselves instead of fighting the
          // segmented control for the same strip.
          Row(
            children: [
              Expanded(
                child: Text(
                  v3Copy(context, zh: '流量趋势', en: 'Usage trend', tw: '流量趨勢'),
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SegmentedButton<int>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? p.lycheeSoft
                        : p.surfaceRaised,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? p.lycheeInk
                        : p.ink,
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                segments: [
                  for (final days in kV3TrafficPeriods)
                    ButtonSegment(
                      value: days,
                      label: Text(
                        v3Copy(
                          context,
                          zh: '$days天',
                          en: '$days days',
                          tw: '$days天',
                        ),
                      ),
                    ),
                ],
                selected: {periodDays},
                showSelectedIcon: false,
                onSelectionChanged: (values) => onPeriodChanged(values.first),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wrap instead of Row: on compact phones the per-day average drops to
          // its own line instead of overflowing the panel edge.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${series.totalGb.toStringAsFixed(2)} GB',
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                v3Copy(
                  context,
                  zh: '近 $periodDays 天合计',
                  en: '$periodDays-day total',
                  tw: '近 $periodDays 天合計',
                ),
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
              if (series.recordedDays > 0) ...[
                const SizedBox(width: 14),
                Text(
                  v3Copy(
                    context,
                    zh: '日均 ${(series.totalGb / periodDays).toStringAsFixed(2)} GB',
                    en: '${(series.totalGb / periodDays).toStringAsFixed(2)} GB/day',
                    tw: '日均 ${(series.totalGb / periodDays).toStringAsFixed(2)} GB',
                  ),
                  style: TextStyle(color: p.inkMuted, fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 146,
            child: series.recordedDays == 0
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.surfaceRaised,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.stacked_line_chart_rounded,
                            color: p.inkMuted,
                            size: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          v3Copy(
                            context,
                            zh: '暂时没有每日流量记录',
                            en: 'No daily usage records yet',
                            tw: '暫時沒有每日流量紀錄',
                          ),
                          style: TextStyle(color: p.inkMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v3Copy(
                            context,
                            zh: '有每日用量后，趋势会画在这里',
                            en: 'The trend draws here once daily usage arrives',
                            tw: '有每日用量後，趨勢會畫在這裡',
                          ),
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : Stack(
                    children: [
                      // Quiet hairline at the bars' feet; every bar bottom sits
                      // exactly 24dp above the chart floor (8dp gap + 16dp labels).
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Container(height: 1, color: p.line),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final spacing = periodDays == 7 ? 10.0 : 4.0;
                          final minChartWidth =
                              periodDays * (periodDays == 7 ? 42.0 : 28.0) +
                              (periodDays - 1) * spacing;
                          final width = constraints.maxWidth > minChartWidth
                              ? constraints.maxWidth
                              : minChartWidth;
                          final scrollable = SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: scrollController,
                            child: SizedBox(
                              width: width,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  for (
                                    var i = 0;
                                    i < series.days.length;
                                    i++
                                  ) ...[
                                    Expanded(
                                      child: _UsageBar(
                                        point: series.days[i],
                                        maxGb: series.maxGb,
                                        details: _DayDetails.forDate(
                                          series.days[i],
                                          usagePoints,
                                        ),
                                        compact: periodDays != 7,
                                        showValue: periodDays == 7,
                                        showLabel:
                                            periodDays == 7 ||
                                            i % (periodDays == 15 ? 3 : 5) ==
                                                0 ||
                                            i == series.days.length - 1,
                                      ),
                                    ),
                                    if (i != series.days.length - 1)
                                      SizedBox(width: spacing),
                                  ],
                                ],
                              ),
                            ),
                          );
                          // The scrollbar only arms when the days overflow
                          // the pane — a fitting range shows no empty track.
                          if (minChartWidth > constraints.maxWidth) {
                            return Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              child: scrollable,
                            );
                          }
                          return scrollable;
                        },
                      ),
                    ],
                  ),
          ),
          if (series.hasGaps && series.recordedDays != 0) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: p.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  v3Copy(
                    context,
                    zh: '灰色表示暂无记录',
                    en: 'Gray: no record',
                    tw: '灰色表示暫無紀錄',
                  ),
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageBar extends StatefulWidget {
  const _UsageBar({
    required this.point,
    required this.maxGb,
    required this.showLabel,
    required this.showValue,
    required this.compact,
    required this.details,
  });
  final TrafficHistoryDay point;
  final bool showValue;
  final double maxGb;
  final bool showLabel;
  final bool compact;
  final _DayDetails details;

  @override
  State<_UsageBar> createState() => _UsageBarState();
}

class _UsageBarState extends State<_UsageBar> {
  // Keyboard focus must surface the bar's readout, and this SDK's tooltip no
  // longer shows on focus by itself: gaining focus pins the tooltip open via
  // ensureTooltipVisible; losing focus dismisses it again.
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final gb = widget.point.gb;
    final ratio = gb == null || widget.maxGb <= 0
        ? 0.0
        : (gb / widget.maxGb).clamp(0.0, 1.0).toDouble();
    final isToday = _isToday(widget.point.date);
    final label = widget.compact
        ? '${widget.point.date.day}'
        : '${widget.point.date.month}/${widget.point.date.day}';
    final value = gb == null
        ? v3Copy(context, zh: '暂无记录', en: 'No record', tw: '暫無紀錄')
        : '${gb.toStringAsFixed(2)} GB';
    final detailsText = widget.details.upload == null ||
            widget.details.download == null
        ? ''
        : v3Copy(
            context,
            zh: '\n上传 ${widget.details.upload!.toStringAsFixed(2)} GB · 下载 ${widget.details.download!.toStringAsFixed(2)} GB',
            en: '\nUpload ${widget.details.upload!.toStringAsFixed(2)} GB · Download ${widget.details.download!.toStringAsFixed(2)} GB',
            tw: '\n上傳 ${widget.details.upload!.toStringAsFixed(2)} GB · 下載 ${widget.details.download!.toStringAsFixed(2)} GB',
          );
    // 7-day view: the daily amount rides on top of each bar so the chart
    // reads at a glance without hovering. 15/30-day views stay caption-free;
    // the tooltip carries the numbers there.
    final caption = gb == null || !widget.showValue
        ? null
        : '${gb >= 10 ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1)}G';
    final message = '${_dayLabel(widget.point.date)}\n$value$detailsText';
    return Tooltip(
      key: _tooltipKey,
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      waitDuration: const Duration(milliseconds: 400),
      showDuration: const Duration(milliseconds: 2500),
      enableFeedback: false,
      child: Semantics(
        label: '${_dayLabel(widget.point.date)}，$value',
        // Hover waits out the 400ms intent delay, so sweeping bars cannot
        // strobe anything (the old toast did); a tap shows the readout on
        // touch; keyboard focus pins it — this SDK's tooltip does not surface
        // on focus by itself, so focus gained calls ensureTooltipVisible and
        // focus lost dismisses it again.
        child: FocusableActionDetector(
          onFocusChange: (focused) {
            if (focused) {
              _tooltipKey.currentState?.ensureTooltipVisible();
            } else {
              RawTooltip.dismissAllToolTips();
            }
          },
          child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isToday ? p.lycheeInk : p.inkMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  Container(
                    width: double.infinity,
                    height: gb == null ? 4 : 6 + 90 * ratio,
                    constraints: BoxConstraints(maxWidth: widget.compact ? 22 : 34),
                    decoration: BoxDecoration(
                      color: gb == null
                          ? p.line
                          : isToday || ratio >= .75
                          ? p.lychee
                          : p.aqua.withValues(alpha: .78),
                      borderRadius: gb == null
                          ? BorderRadius.circular(V3Radius.glyph)
                          : const BorderRadius.vertical(
                              top: Radius.circular(V3Radius.glyph),
                            ),
                    ),
                  ),
                  // Breathing room between the bars and the date labels.
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 16,
                    child: widget.showLabel
                        ? Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isToday ? p.ink : p.inkMuted,
                              fontSize: 10,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

/// Today check for the trend chart emphasis.
bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

int? _daysUntilReset(int? resetDay) {
  if (resetDay == null || resetDay < 1 || resetDay > 31) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime targetFor(int year, int month) {
    final nextMonth = month == 12
        ? DateTime(year + 1, 1, 1)
        : DateTime(year, month + 1, 1);
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

/// V3 copy must also render in isolated widget previews without ARB delegates.
String _v3YesterdayComparison(
  BuildContext context,
  List<TrafficUsagePoint> usage,
  double today,
) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  final hasRecord = usage.any(
    (point) =>
        point.date.year == yesterday.year &&
        point.date.month == yesterday.month &&
        point.date.day == yesterday.day,
  );
  if (!hasRecord) {
    return v3Copy(
      context,
      zh: '昨日暂无记录',
      en: 'No data for yesterday',
      tw: '昨日暫無紀錄',
    );
  }
  final previous = trafficForDay(usage, yesterday);
  final change = relativeChangePercent(current: today, previous: previous);
  if (change == null) {
    final total = previous.toStringAsFixed(2);
    return v3Copy(
      context,
      zh: '昨日 $total GB',
      en: 'Yesterday $total GB',
      tw: '昨日 $total GB',
    );
  }
  final rounded = change.abs() < 0.5 ? 0 : change.round();
  final percent = rounded > 0 ? '+$rounded%' : '$rounded%';
  return v3Copy(
    context,
    zh: '较昨日 $percent',
    en: 'Vs yesterday $percent',
    tw: '較昨日 $percent',
  );
}

/// Header refresh with in-flight feedback (round-3 audit F32): while the
/// refresh runs the icon spins (18px) and the button stands down, so a slow
/// refresh no longer reads as nothing happened. Local state only — the
/// controller stays the source of truth (refreshData is single-flight and
/// reports failure through dataLoadError).
class _RefreshIconButton extends StatefulWidget {
  const _RefreshIconButton({required this.tooltip, required this.onRefresh});

  final String tooltip;
  final Future<void> Function() onRefresh;

  @override
  State<_RefreshIconButton> createState() => _RefreshIconButtonState();
}

class _RefreshIconButtonState extends State<_RefreshIconButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _run,
      icon: _busy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.inkMuted,
              ),
            )
          : const Icon(Icons.refresh_rounded),
    );
  }
}

/// The refresh failed while data is on screen: a quiet warning strip above
/// the panels names the failure and offers the retry, so a refresh never
/// fails silently (round-3 audit F12). The dashboard's data-warning tile is
/// the voice reference.
class _DataErrorRow extends StatelessWidget {
  const _DataErrorRow({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(V3Radius.field),
        border: Border.all(color: p.warning.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: p.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.warningInk, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              foregroundColor: p.warningInk,
              side: BorderSide(color: p.warning.withValues(alpha: .4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V3Radius.control),
              ),
            ),
            child: Text(
              v3Copy(context, zh: '重试', en: 'Retry', tw: '重試'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// First-load placeholders in the shape of the page's three panels, so the
/// real values hand in without a 0.0 GB flash (round-3 audit F12; the nodes
/// page's loading-space rule). Static blocks — no motion to gate.
class _TrafficSkeleton extends StatelessWidget {
  const _TrafficSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    Widget panel({
      Color? color,
      EdgeInsets padding = const EdgeInsets.all(20),
      required Widget child,
    }) => Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: child,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quota hero: label row, big figure, gauge, bottom values.
        panel(
          color: p.hero,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: V3SkeletonBlock(height: 11)),
                  SizedBox(width: 12),
                  V3SkeletonBlock(width: 44, height: 11),
                ],
              ),
              SizedBox(height: 16),
              V3SkeletonBlock(width: 132, height: 34),
              SizedBox(height: 16),
              // The gauge placeholder sits at the loaded bar's exact height.
              V3SkeletonBlock(height: 7),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: V3SkeletonBlock(height: 11)),
                  SizedBox(width: 12),
                  Expanded(child: V3SkeletonBlock(height: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Stat-tile band: the same 2/3-column grid the loaded band uses.
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= V3Layout.paneCompact ? 3 : 2;
            return Column(
              children: [
                for (var i = 0; i < 6; i += cols) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var j = i; j < (i + cols).clamp(0, 6); j++) ...[
                        if (j > i) const SizedBox(width: 12),
                        const Expanded(child: _StatTileSkeleton()),
                      ],
                    ],
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        // Trend panel: title + range control, totals line, bar placeholders.
        panel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(child: V3SkeletonBlock(height: 13)),
                  SizedBox(width: 12),
                  V3SkeletonBlock(
                    width: 150,
                    height: 30,
                    radius: V3Radius.control,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const V3SkeletonBlock(width: 110, height: 18),
              const SizedBox(height: 18),
              SizedBox(
                height: 118,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in const [86, 52, 98, 40, 74, 104, 30])
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: V3SkeletonBlock(width: 22, height: h.toDouble()),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One placeholder stat tile, in the shape of [V3StatTile].
class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.card),
        border: Border.all(color: p.hairline),
        boxShadow: p.shadows,
      ),
      child: const Row(
        children: [
          V3SkeletonBlock(width: 30, height: 30, radius: V3Radius.control),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FractionallySizedBox(
                  widthFactor: .6,
                  alignment: Alignment.centerLeft,
                  child: V3SkeletonBlock(height: 11),
                ),
                SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: .4,
                  alignment: Alignment.centerLeft,
                  child: V3SkeletonBlock(height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

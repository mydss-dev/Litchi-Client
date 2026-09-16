import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
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
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.data_usage_rounded, color: p.lychee, size: 34),
              const SizedBox(height: 16),
              Text(
                '还没有可统计的套餐',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '激活套餐后，这里会显示每天的流量趋势、重置时间与剩余额度。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => controller.goToPage(AppPage.shop),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('去选择套餐'),
              ),
            ],
          ),
        ),
      );
    }

    final points = _usagePoints(controller, _days);
    final totalPeriod = points.fold<double>(0, (sum, point) => sum + point.gb);
    final average = points.isEmpty ? 0.0 : totalPeriod / points.length;
    final maxGb = points.fold<double>(
      0,
      (max, point) => point.gb > max ? point.gb : max,
    );
    final traffic = controller.traffic;
    final usedRatio = traffic.totalGb <= 0
        ? 0.0
        : (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '使用概览',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '流量',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '看清今天用了多少、套餐还剩多少，以及最近的使用节奏。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  V3BackToAccount(
                    onTap: () => controller.goToPage(AppPage.account),
                  ),
                  IconButton(
                    tooltip: '刷新流量',
                    onPressed: controller.refreshData,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              compact
                  ? Column(
                      children: [
                        _QuotaPanel(
                          controller: controller,
                          usedRatio: usedRatio,
                        ),
                        const SizedBox(height: 16),
                        _TimingPanel(controller: controller),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _QuotaPanel(
                            controller: controller,
                            usedRatio: usedRatio,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _TimingPanel(controller: controller),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              _TrendPanel(
                points: points,
                maxGb: maxGb,
                periodDays: _days,
                periodTotal: totalPeriod,
                average: average,
                today: controller.todayTrafficGb,
                onPeriodChanged: (days) => setState(() => _days = days),
              ),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: p.night,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '套餐流量',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              Text(
                '已用 ${(usedRatio * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: p.aqua,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${traffic.remainGb.toStringAsFixed(1)} GB',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '剩余流量',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: usedRatio,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(p.lychee),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _QuotaValue(
                  label: '已使用',
                  value: '${traffic.usedGb.toStringAsFixed(1)} GB',
                ),
              ),
              Expanded(
                child: _QuotaValue(
                  label: '总额度',
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
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TimingPanel extends StatelessWidget {
  const _TimingPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final resetDays = _daysUntilReset(controller.resetDay);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '使用与有效期',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          _TimingRow(
            icon: Icons.today_rounded,
            label: '今日已用',
            value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB',
            accent: p.lychee,
          ),
          _TimingRow(
            icon: Icons.event_available_rounded,
            label: '套餐有效期',
            value: controller.planExpiryLabel,
            accent: p.aqua,
          ),
          _TimingRow(
            icon: Icons.restart_alt_rounded,
            label: '流量重置',
            value: controller.resetDay == null
                ? '未提供'
                : resetDays == null
                ? '每月 ${controller.resetDay} 日'
                : '$resetDays 天后',
            accent: p.success,
          ),
          _TimingRow(
            icon: Icons.devices_rounded,
            label: '在线设备',
            value: controller.aliveIp == null
                ? '--'
                : controller.deviceLimit == null
                ? '${controller.aliveIp}'
                : '${controller.aliveIp} / ${controller.deviceLimit}',
            accent: p.warning,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 15),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: p.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.points,
    required this.maxGb,
    required this.periodDays,
    required this.periodTotal,
    required this.average,
    required this.today,
    required this.onPeriodChanged,
  });

  final List<_UsagePoint> points;
  final double maxGb;
  final int periodDays;
  final double periodTotal;
  final double average;
  final double today;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USAGE TREND',
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$periodDays 天共使用 ${periodTotal.toStringAsFixed(2)} GB',
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7天')),
                  ButtonSegment(value: 30, label: Text('30天')),
                ],
                selected: {periodDays},
                showSelectedIcon: false,
                onSelectionChanged: (value) => onPeriodChanged(value.first),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: points.isEmpty
                ? Center(
                    child: Text(
                      '暂时没有每日流量记录',
                      style: TextStyle(color: p.inkMuted, fontSize: 11),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final gap = periodDays == 7 ? 12.0 : 3.0;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < points.length; i++) ...[
                            Expanded(
                              child: _UsageBar(
                                point: points[i],
                                maxGb: maxGb,
                                showLabel:
                                    periodDays == 7 ||
                                    i % 5 == 0 ||
                                    i == points.length - 1,
                              ),
                            ),
                            if (i != points.length - 1) SizedBox(width: gap),
                          ],
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _TrendMetric(
                  label: '日均',
                  value: '${average.toStringAsFixed(2)} GB',
                ),
              ),
              Expanded(
                child: _TrendMetric(
                  label: '今日',
                  value: '${today.toStringAsFixed(2)} GB',
                ),
              ),
              Expanded(
                child: _TrendMetric(
                  label: '峰值',
                  value: '${maxGb.toStringAsFixed(2)} GB',
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

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.point,
    required this.maxGb,
    required this.showLabel,
  });

  final _UsagePoint point;
  final double maxGb;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final ratio = maxGb <= 0
        ? 0.0
        : (point.gb / maxGb).clamp(0.0, 1.0).toDouble();
    final height = 18 + 110 * ratio;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Tooltip(
          message: '${point.gb.toStringAsFixed(2)} GB',
          child: Container(
            width: double.infinity,
            height: height,
            constraints: const BoxConstraints(maxWidth: 34),
            decoration: BoxDecoration(
              color: ratio >= 0.75 ? p.lychee : p.aqua.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 16,
          child: showLabel
              ? Text(
                  '${point.date.month}/${point.date.day}',
                  maxLines: 1,
                  style: TextStyle(color: p.inkMuted, fontSize: 8),
                )
              : null,
        ),
      ],
    );
  }
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({
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
        Text(label, style: TextStyle(color: p.inkMuted, fontSize: 9)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: p.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _UsagePoint {
  const _UsagePoint(this.date, this.gb);

  final DateTime date;
  final double gb;
}

List<_UsagePoint> _usagePoints(AppController controller, int days) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.subtract(Duration(days: days - 1));
  if (controller.trafficUsage.isNotEmpty) {
    return controller.trafficUsage
        .where((point) {
          final date = DateTime(
            point.date.year,
            point.date.month,
            point.date.day,
          );
          return !date.isBefore(cutoff) && !date.isAfter(today);
        })
        .map((point) => _UsagePoint(point.date, point.totalGb))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  final fallback = controller.dailyUsage;
  if (fallback.isEmpty) return const [];
  final slice = fallback.length > days
      ? fallback.sublist(fallback.length - days)
      : fallback;
  return [
    for (var i = 0; i < slice.length; i++)
      _UsagePoint(
        today.subtract(Duration(days: slice.length - 1 - i)),
        slice[i],
      ),
  ];
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

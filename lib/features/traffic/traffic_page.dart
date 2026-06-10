import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/models/mock_data.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_select.dart';
import '../../shared/widgets/log_panel.dart';
import '../../shared/widgets/page_header.dart';

/// Statistics page (§13): traffic overview (donut) + daily usage (bars) +
/// online devices + login records.
class TrafficPage extends StatefulWidget {
  const TrafficPage({super.key});

  @override
  State<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends State<TrafficPage> {
  String _period = '月用';

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(title: '统计', subtitle: '查看流量概览和近期登录记录'),
              ),
              AppSelect<String>(
                value: _period,
                items: const ['日用', '月用', '年用'],
                labelOf: (v) => v,
                onChanged: (v) => setState(() => _period = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SummaryCard(),
          const SizedBox(height: 16),
          const _DailyUsageCard(),
          const SizedBox(height: 16),
          const _DevicesCard(),
          const SizedBox(height: 16),
          const _LoginRecordsCard(),
          const SizedBox(height: 16),
          _LogCard(logStream: ctrl.coreLogStream),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.logStream});

  final Stream<String> logStream;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: c.softBorder),
      ),
      child: LogPanel(logStream: logStream),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    final t = AppScope.of(context).traffic;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 580 so the stats+donut sit side-by-side at the real content width.
          final wide = constraints.maxWidth >= 580;
          final stats = _SummaryStats(traffic: t);
          final donut = _TrafficDonut(percent: t.usedPercent);
          if (wide) {
            return Row(
              children: [
                Expanded(child: stats),
                const SizedBox(width: 18),
                SizedBox(width: 150, height: 150, child: donut),
              ],
            );
          }
          return Column(
            children: [
              stats,
              const SizedBox(height: 18),
              SizedBox(width: 150, height: 150, child: donut),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryStats extends StatelessWidget {
  const _SummaryStats({required this.traffic});

  final TrafficModel traffic;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('总计流量', style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${traffic.totalGb.toInt()}',
                style: AppTextStyles.largeNumber(fontSize: 34).copyWith(color: c.textPrimary)),
            const SizedBox(width: 6),
            Text('GB', style: AppTextStyles.sectionTitle.copyWith(color: c.textMuted)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _legend(c, c.primary, '已用', '${traffic.usedGb.toInt()} GB'),
            const SizedBox(width: 28),
            _legend(c, c.surfaceMuted, '剩余', '${traffic.remainGb.toInt()} GB',
                dotBorder: true),
          ],
        ),
      ],
    );
  }

  Widget _legend(AppColors c, Color dot, String label, String value,
      {bool dotBorder = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            border: dotBorder ? Border.all(color: c.border) : null,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            Text(value, style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _TrafficDonut extends StatelessWidget {
  const _TrafficDonut({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: 0,
            centerSpaceRadius: 52,
            sections: [
              PieChartSectionData(
                value: percent,
                radius: 18,
                showTitle: false,
                gradient: AppPalette.brandGradient,
              ),
              PieChartSectionData(
                value: 100 - percent,
                radius: 18,
                showTitle: false,
                color: c.surfaceMuted,
              ),
            ],
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${percent.toStringAsFixed(1)}%',
                style: AppTextStyles.largeNumber(fontSize: 22).copyWith(color: c.textPrimary)),
            Text('已用', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _DailyUsageCard extends StatelessWidget {
  const _DailyUsageCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final data = AppScope.of(context).dailyUsage;
    final maxV = data.reduce((a, b) => a > b ? a : b);

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('每日使用情况',
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 18),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: (maxV / 10).ceil() * 10,
                alignment: BarChartAlignment.spaceBetween,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: c.softBorder, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: 10,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}',
                        style: AppTextStyles.caption.copyWith(
                            color: c.textMuted, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        // Label every 5th day to avoid clutter.
                        if (i % 5 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${i + 1}',
                              style: AppTextStyles.caption.copyWith(
                                  color: c.textMuted, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < data.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: data[i],
                          width: 6,
                          borderRadius: BorderRadius.circular(3),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppPalette.brandStart, AppPalette.brandEnd],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final devices = MockData.devices;
    final online = devices.where((d) => d.online).length;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.monitorSmartphone, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Text('在线设备',
                  style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
              const Spacer(),
              Text('$online / 5',
                  style: AppTextStyles.bodyStrong.copyWith(color: c.primary)),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < devices.length; i++) ...[
            _deviceRow(c, devices[i]),
            if (i != devices.length - 1) Divider(color: c.softBorder, height: 16),
          ],
        ],
      ),
    );
  }

  Widget _deviceRow(AppColors c, DeviceModel d) {
    final icon = d.platform.contains('Windows')
        ? LucideIcons.monitor
        : d.platform.contains('iOS')
            ? LucideIcons.smartphone
            : LucideIcons.laptop;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.iconDefault),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.name, style: AppTextStyles.body.copyWith(color: c.textPrimary)),
              Text(d.platform,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        Text(d.lastActive,
            style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        const SizedBox(width: 10),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: d.online ? c.success : c.iconMuted,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _LoginRecordsCard extends StatelessWidget {
  const _LoginRecordsCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final records = MockData.loginRecords;

    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Text('登录记录',
                  style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < records.length; i++) ...[
            _recordRow(c, records[i]),
            if (i != records.length - 1) Divider(color: c.softBorder, height: 16),
          ],
        ],
      ),
    );
  }

  Widget _recordRow(AppColors c, LoginRecord r) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r.location,
                      style: AppTextStyles.body.copyWith(color: c.textPrimary)),
                  const SizedBox(width: 8),
                  if (r.suspicious)
                    AppBadge(
                      text: '异常',
                      background: c.dangerSoft,
                      textColor: c.danger,
                      fontSize: 10,
                      height: 18,
                    ),
                ],
              ),
              Text(r.device,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        Text(r.time, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
      ],
    );
  }
}

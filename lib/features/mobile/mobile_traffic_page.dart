import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_toast.dart';
import 'mobile_back_button.dart';
import 'mobile_page_header.dart';

class MobileTrafficPage extends StatefulWidget {
  const MobileTrafficPage({super.key});

  @override
  State<MobileTrafficPage> createState() => _MobileTrafficPageState();
}

class _MobileTrafficPageState extends State<MobileTrafficPage> {
  Future<void> _refresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final asChild = ctrl.mobileProfileChildPage;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asChild)
            Row(
              children: [
                MobileBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '用量统计',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                  ),
                ),
              ],
            )
          else
            const MobilePageHeader(title: '用量', subtitle: '查看流量、重置与近期记录'),
          const SizedBox(height: 16),
          _TrafficSummaryCard(ctrl: ctrl),
          const SizedBox(height: 12),
          _TrafficStatsGrid(ctrl: ctrl),
          const SizedBox(height: 12),
          _TrafficRecordsCard(records: ctrl.trafficUsage),
        ],
      ),
    );
  }
}

class _TrafficSummaryCard extends StatelessWidget {
  const _TrafficSummaryCard({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final traffic = ctrl.traffic;
    final percent = traffic.totalGb > 0
        ? (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TrafficIcon(icon: LucideIcons.chartPie, color: c.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '流量概览',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已用 ${_formatGb(traffic.usedGb)} / 总量 ${_formatGb(traffic.totalGb)}',
                      style: AppTextStyles.caption.copyWith(
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: AppTextStyles.caption.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatGb(traffic.remainGb),
            style: AppTextStyles.pageTitle.copyWith(
              color: c.textPrimary,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '剩余流量',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: percent,
              backgroundColor: c.surfaceMuted,
              color: c.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrafficStatsGrid extends StatelessWidget {
  const _TrafficStatsGrid({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TrafficStatCard(
                icon: LucideIcons.calendarDays,
                title: '今日流量',
                value: _formatGb(ctrl.todayTrafficGb),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrafficStatCard(
                icon: LucideIcons.refreshCw,
                title: '流量重置',
                value: _formatResetDay(ctrl.resetDay),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TrafficStatCard(
                icon: LucideIcons.monitorSmartphone,
                title: '设备数',
                value: _formatDeviceLimit(ctrl.deviceLimit),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrafficStatCard(
                icon: LucideIcons.calendarClock,
                title: '到期时间',
                value: ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrafficStatCard extends StatelessWidget {
  const _TrafficStatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 84,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          _TrafficIcon(icon: icon, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
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

class _TrafficRecordsCard extends StatelessWidget {
  const _TrafficRecordsCard({required this.records});

  final List<TrafficUsagePoint> records;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final data = [...records]..sort((a, b) => b.date.compareTo(a.date));
    final latest = data.take(7).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TrafficIcon(icon: LucideIcons.activity, color: c.primary),
              const SizedBox(width: 10),
              Text(
                '近期记录',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (latest.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  '暂无流量记录',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
            )
          else
            for (final item in latest) ...[
              _TrafficRecordRow(point: item),
              if (item != latest.last)
                Divider(height: 18, color: c.softBorder),
            ],
        ],
      ),
    );
  }
}

class _TrafficRecordRow extends StatelessWidget {
  const _TrafficRecordRow({required this.point});

  final TrafficUsagePoint point;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            _formatDate(point.date),
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatGb(point.totalGb),
              style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 3),
            Text(
              '上 ${_formatGb(point.uploadGb)}  下 ${_formatGb(point.downloadGb)}',
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrafficIcon extends StatelessWidget {
  const _TrafficIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

String _formatGb(double value) {
  if (value <= 0) return '0.0 GB';
  return '${value.toStringAsFixed(1)} GB';
}

String _formatResetDay(int? resetDay) {
  if (resetDay == null || resetDay == 0) return '--';
  return '每月 $resetDay 日';
}

String _formatDeviceLimit(int? deviceLimit) {
  if (deviceLimit == null) return '--';
  return deviceLimit > 0 ? '$deviceLimit 台' : '不限';
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

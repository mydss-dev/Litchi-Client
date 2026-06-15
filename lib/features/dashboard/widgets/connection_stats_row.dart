import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

/// Formats bytes-per-second into a human-readable (value, unit) pair.
(String, String) formatSpeed(int bps) {
  if (bps <= 0) return ('--', '');
  if (bps < 1024) return ('$bps', 'B/s');
  if (bps < 1024 * 1024) return ((bps / 1024).toStringAsFixed(1), 'KB/s');
  return ((bps / (1024 * 1024)).toStringAsFixed(1), 'MB/s');
}

class ConnectionStatsRow extends StatelessWidget {
  const ConnectionStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final latency = ctrl.currentNode.latency;
    final latencyValue = latency > 0 && latency < 9999
        ? latency.toString()
        : '--';
    final latencyCard = _ConnectionStatCard(
      label: '当前延迟',
      value: latencyValue,
      unit: 'ms',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final threeCols = constraints.maxWidth >= 560;

        // Speed values update every second via ValueNotifier — isolated from
        // the global AppScope rebuild to avoid per-second tree-wide diffs.
        return ValueListenableBuilder<int>(
          valueListenable: ctrl.downBpsNotifier,
          builder: (context, downBps, _) => ValueListenableBuilder<int>(
            valueListenable: ctrl.upBpsNotifier,
            builder: (context, upBps, _) {
              final (downValue, downUnit) = formatSpeed(downBps);
              final (upValue, upUnit) = formatSpeed(upBps);
              final cards = [
                latencyCard,
                _ConnectionStatCard(
                  label: '下载速度',
                  value: downValue,
                  unit: downUnit,
                ),
                _ConnectionStatCard(
                  label: '上传速度',
                  value: upValue,
                  unit: upUnit,
                ),
              ];

              if (threeCols) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 14),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    cards[i],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _ConnectionStatCard extends StatelessWidget {
  const _ConnectionStatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: c.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.largeNumber(
                    fontSize: 23,
                  ).copyWith(color: c.textPrimary, height: 1),
                ),
              ),
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  unit,
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

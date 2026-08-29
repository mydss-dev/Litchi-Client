import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';

/// Current-latency stat card. The upload/download speed cards were removed
/// (they added no real value on the home screen); latency is the one live
/// metric worth surfacing here.
class ConnectionStatsRow extends StatelessWidget {
  const ConnectionStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final latency = ctrl.currentNode.latency;
    final latencyValue = latency > 0 && latency < 9999
        ? latency.toString()
        : '--';

    return _ConnectionStatCard(
      label: context.l10n.currentLatency,
      value: latencyValue,
      unit: 'ms',
      dimmed: !ctrl.coreRunning,
    );
  }
}

class _ConnectionStatCard extends StatelessWidget {
  const _ConnectionStatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.dimmed = false,
  });

  final String label;
  final String value;
  final String unit;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Opacity(
      opacity: dimmed ? 0.38 : 1.0,
      child: AppCard(
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
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import '../utils/latency_status.dart';

enum NodeLatencyStyle { text, badge, dot }

/// Consistent rendering for untested, testing, measured, and timed-out nodes.
class NodeLatency extends StatelessWidget {
  const NodeLatency({
    super.key,
    required this.latency,
    this.style = NodeLatencyStyle.text,
  });

  final int latency;
  final NodeLatencyStyle style;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = LatencyStatus.color(latency, c);

    if (latency < 0) {
      final size = switch (style) {
        NodeLatencyStyle.dot => 8.0,
        NodeLatencyStyle.badge => 16.0,
        NodeLatencyStyle.text => 18.0,
      };
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: style == NodeLatencyStyle.dot ? 1.5 : 2,
          color: color,
        ),
      );
    }

    final label = LatencyStatus.label(latency);
    return switch (style) {
      NodeLatencyStyle.text => Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      NodeLatencyStyle.badge => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      NodeLatencyStyle.dot => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.menu.copyWith(color: color)),
        ],
      ),
    };
  }
}

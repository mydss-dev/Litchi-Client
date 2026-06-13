import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileShopPage extends StatelessWidget {
  const MobileShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('套餐', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
        const SizedBox(height: 3),
        Text(
          '选择适合你的订阅计划',
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ctrl.plans.isEmpty
              ? Center(
                  child: Text(
                    '暂无套餐信息',
                    style: AppTextStyles.body.copyWith(color: c.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: ctrl.plans.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _PlanCard(plan: ctrl.plans[index]),
                ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final PlanModel plan;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final price =
        plan.monthlyPrice ??
        plan.oneTimePrice ??
        plan.quarterlyPrice ??
        plan.yearlyPrice;
    final priceLabel = price == null ? '--' : '¥${price.toStringAsFixed(2)}';
    final subtitle = plan.features.isEmpty
        ? plan.capacity
        : '${plan.capacity} · ${plan.features.take(2).join(' / ')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(LucideIcons.packageCheck, color: c.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            priceLabel,
            style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
          ),
        ],
      ),
    );
  }
}

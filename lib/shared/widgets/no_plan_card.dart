import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'app_card.dart';

class NoPlanCard extends StatelessWidget {
  const NoPlanCard({super.key, this.onPurchase});

  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(20),
      shadow: AppCardShadow.soft,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(LucideIcons.packageOpen, color: c.primary, size: 23),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.noCurrentPlan,
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.noPlanDescription,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
          if (onPurchase != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: onPurchase,
                icon: const Icon(LucideIcons.shoppingBag, size: 16),
                label: Text(context.l10n.buyPlans),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

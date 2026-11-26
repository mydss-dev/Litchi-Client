import 'package:flutter/material.dart';

import '../../app/plan_presentation.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';
import 'v3_plan_labels.dart';

/// Shows a compact subtitle on Account and the full details in its sheet.
class V3MobilePlanSummary extends StatelessWidget {
  const V3MobilePlanSummary({
    super.key,
    required this.plan,
    this.onRenew,
    this.inline = false,
  });

  final PlanPresentation plan;
  final VoidCallback? onRenew;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final date = plan.expiryDate;
    final notSubscribed = plan.statusKind == PlanStatus.notSubscribed;
    final statusLabel = v3PlanStatusLabel(context, plan.statusKind);
    final statusColor = v3PlanStatusColor(p, plan.statusKind);
    final timeLeft = date?.difference(DateTime.now());
    final showRenewal =
        plan.expiryKind != PlanExpiryKind.permanent &&
        (plan.statusKind == PlanStatus.expired ||
            (plan.statusKind == PlanStatus.normal &&
                timeLeft != null &&
                timeLeft <= const Duration(days: 7)));
    final actionLabel = notSubscribed
        ? v3Copy(context, zh: '查看套餐', en: 'View plans', tw: '查看方案')
        : v3Copy(context, zh: '续费', en: 'Renew', tw: '續費');
    final actionStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
    );
    final title = notSubscribed
        ? v3PlanStatusLabel(context, plan.statusKind)
        : plan.name == '套餐名称待同步'
        ? v3Copy(
            context,
            zh: '套餐信息待同步',
            en: 'Plan details pending',
            tw: '方案資料待同步',
          )
        : plan.name;
    final detail = switch (plan.expiryKind) {
      PlanExpiryKind.date when date != null => v3Copy(
        context,
        zh: '${date.year}.${date.month}.${date.day} 到期',
        en: 'Expires ${MaterialLocalizations.of(context).formatCompactDate(date)}',
        tw: '${date.year}.${date.month}.${date.day} 到期',
      ),
      PlanExpiryKind.permanent => v3Copy(
        context,
        zh: '永久有效',
        en: 'No expiry',
        tw: '永久有效',
      ),
      _ => null,
    };
    if (inline) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: p.inkMuted, fontSize: 11),
      );
    }
    final showAction =
        onRenew != null &&
        (notSubscribed || plan.expiryKind != PlanExpiryKind.permanent);
    final action = Text(actionLabel);
    const actionKey = ValueKey('v3-account-renew');
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!notSubscribed) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (detail != null)
                      Text(
                        detail,
                        style: TextStyle(color: p.inkMuted, fontSize: 12),
                      ),
                    Container(
                      key: const ValueKey('v3-account-plan-status'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (showAction) ...[
          const SizedBox(width: 8),
          if (notSubscribed || showRenewal)
            FilledButton(
              key: actionKey,
              onPressed: onRenew,
              style: actionStyle,
              child: action,
            )
          else
            TextButton(
              key: actionKey,
              onPressed: onRenew,
              style: TextButton.styleFrom(
                foregroundColor: p.inkMuted,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: action,
            ),
        ],
      ],
    );
  }
}

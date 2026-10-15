// Machine-readable plan presentation helpers for V3: labels and colors
// switch on PlanStatus/PlanExpiryKind, never on the Chinese display strings,
// so copy tweaks cannot silently break status coloring and labels (round-3
// audit N14).
import 'package:flutter/widgets.dart';

import '../../app/plan_presentation.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// Status label for the machine-readable status kind. The Chinese strings
/// mirror [PlanPresentation.resolve]'s display strings, so the migration from
/// `plan.status` reads identically in zh.
String v3PlanStatusLabel(BuildContext context, PlanStatus kind) {
  return switch (kind) {
    PlanStatus.normal => v3Copy(context, zh: '正常', en: 'Normal', tw: '正常'),
    PlanStatus.pendingSync => v3Copy(context,
        zh: '状态待同步', en: 'Status pending sync', tw: '狀態待同步'),
    PlanStatus.expired => v3Copy(context, zh: '到期', en: 'Expired', tw: '到期'),
    PlanStatus.banned => v3Copy(context, zh: '封禁', en: 'Banned', tw: '封禁'),
    PlanStatus.quotaExhausted => v3Copy(context,
        zh: '流量已用尽', en: 'Quota exhausted', tw: '流量已用盡'),
    PlanStatus.notSubscribed => v3Copy(context,
        zh: '未开通', en: 'Not subscribed', tw: '未開通'),
  };
}

/// Expiry line for the plan card/chip: formats by machine-readable kind
/// instead of matching on the Chinese display string.
String v3PlanExpiryLabel(BuildContext context, PlanPresentation plan) {
  final d = plan.expiryDate;
  final iso = d == null
      ? null
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return switch (plan.expiryKind) {
    PlanExpiryKind.none => v3Copy(context,
        zh: '尚未开通套餐', en: 'No plan yet', tw: '尚未開通套餐'),
    PlanExpiryKind.permanent => v3Copy(context,
        zh: '永久有效', en: 'Never expires', tw: '永久有效'),
    PlanExpiryKind.pendingSync => v3Copy(context,
        zh: '有效期待同步', en: 'Validity pending sync', tw: '有效期待同步'),
    PlanExpiryKind.date when iso != null => v3Copy(context,
        zh: '到期 $iso', en: 'Expires $iso', tw: '到期 $iso'),
    PlanExpiryKind.date => v3Copy(context,
        zh: '有效期待同步', en: 'Validity pending sync', tw: '有效期待同步'),
  };
}

/// Chip label: the plan name alone when there is nothing degraded to add,
/// "name · status" otherwise — mirrors [PlanPresentation.shortLabel] but
/// localized and kind-based.
String v3PlanShortLabel(BuildContext context, PlanPresentation plan) {
  if (plan.name == '暂无套餐' || plan.statusKind == PlanStatus.normal) {
    return plan.name;
  }
  return '${plan.name} · ${v3PlanStatusLabel(context, plan.statusKind)}';
}

/// Status color: green is a measured/confirmed state, red a hard failure,
/// amber a degraded-but-real state, neutral when the panel has not told us.
Color v3PlanStatusColor(V3Palette p, PlanStatus kind) {
  return switch (kind) {
    PlanStatus.normal => p.success,
    PlanStatus.banned => p.danger,
    PlanStatus.expired => p.warning,
    PlanStatus.quotaExhausted => p.warning,
    PlanStatus.pendingSync => p.inkMuted,
    PlanStatus.notSubscribed => p.inkMuted,
  };
}

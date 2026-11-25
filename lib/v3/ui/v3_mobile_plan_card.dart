import 'package:flutter/material.dart';
import 'package:forui/forui.dart' show FCard, FCardStyle;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import 'v3_locale_copy.dart';
import 'v3_plan_labels.dart';

/// The same compact, real-data subscription hero on Account and Usage.
/// Account opens Usage; the in-page Usage copy is informational.
/// Approved V3: the account subscription is the single soft coral hero.
class V3MobilePlanCard extends StatelessWidget {
  const V3MobilePlanCard({super.key, required this.controller,
    this.onOpenUsage, this.onRenew});
  final AppController controller;
  final VoidCallback? onOpenUsage;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final plan = PlanPresentation.fromController(controller);
    final expires = plan.expiryDate;
    final days = expires?.difference(DateTime.now());
    final expiryDate = expires == null ? '—'
      : '${expires.year}.${expires.month.toString().padLeft(2, '0')}.${expires.day.toString().padLeft(2, '0')}';
    final remaining = days != null && days > Duration.zero
        ? v3Copy(context, zh: '${days.inDays} 天',
            en: '${days.inDays} days', tw: '${days.inDays} 天')
        : '—';
    final ink = dark ? const Color(0xFFFFF7F5) : const Color(0xFF25262A);
    final secondary = dark ? const Color(0xFFE1C8C7)
      : const Color(0xFF87716F);
    final dateText = switch (plan.expiryKind) {
      PlanExpiryKind.permanent => v3Copy(context, zh: '永久',
        en: 'Permanent', tw: '永久'),
      PlanExpiryKind.date => expiryDate,
      _ => '—',
    };
    final verified = plan.statusKind == PlanStatus.normal;
    final status = verified
      ? v3Copy(context, zh: '有效中', en: 'Active', tw: '有效中')
      : v3PlanStatusLabel(context, plan.statusKind);
    return Semantics(
      button: onOpenUsage != null,
      label: onOpenUsage == null ? null : v3Copy(context,
        zh: '查看流量用量', en: 'View data usage', tw: '查看流量用量'),
      child: GestureDetector(
        key: const ValueKey('v3-mobile-plan-card'),
        behavior: HitTestBehavior.opaque,
        onTap: onOpenUsage,
        child: FCard(
      style: FCardStyle(
        decoration: const BoxDecoration(),
        titleTextStyle: TextStyle(color: ink,
          fontSize: 16, fontWeight: FontWeight.w600),
        subtitleTextStyle: TextStyle(color: secondary, fontSize: 13),
        padding: EdgeInsets.zero),
      child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: dark
            ? const [Color(0xFF453338), Color(0xFF3B3036),
                Color(0xFF343038)]
            : const [Color(0xFFFFF5F1), Color(0xFFFFEDE8),
                Color(0xFFFFE5E0)],
        ),
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: dark
            ? const Color(0xFF68494C) : const Color(0xFFF7DAD4)),
        boxShadow: dark ? null : const [BoxShadow(
          color: Color(0x12B86053), blurRadius: 28, offset: Offset(0, 11))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(top: -95, right: -75,
          child: IgnorePointer(child: Container(
            width: 208, height: 208,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: .45)),
              shape: BoxShape.circle)))),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                height: 24, width: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: dark ? .16 : .69),
                  borderRadius: BorderRadius.circular(9)),
                child: Icon(LucideIcons.crown, size: 15,
                  color: dark ? const Color(0xFFFFD1C7)
                    : const Color(0xFFC55D4B)),
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(v3Copy(context, zh: '订阅计划',
                    en: 'Subscription plan', tw: '訂閱計劃'),
                style: TextStyle(color: dark ? const Color(0xFFFFD1C7)
                  : const Color(0xFFA45A4F),
                  fontSize: 11, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: dark ? .12 : .68),
                  borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: verified ? const Color(0xFF3BAC77)
                        : const Color(0xFFA4A0A5))),
                  const SizedBox(width: 6),
                  Text(status, style: TextStyle(
                    color: dark ? const Color(0xFFDFECE5)
                      : const Color(0xFF597261),
                    fontSize: 10, fontWeight: FontWeight.w800)),
                ]),
              ),
              if (onOpenUsage != null) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight, size: 15, color: secondary),
              ],
            ]),
            const SizedBox(height: 10),
            Text(v3Copy(context, zh: '当前套餐',
                en: 'CURRENT PLAN', tw: '目前方案'),
              style: TextStyle(color: dark ? const Color(0xFFE2B0AC)
                : const Color(0xFFB5746B),
                fontSize: 10, fontWeight: FontWeight.w700,
                letterSpacing: 1.2)),
            const SizedBox(height: 3),
            Text(controller.hasPlan ? plan.name :
              v3Copy(context, zh: '暂无套餐',
                en: 'No plan', tw: '暫無套餐'),
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: ink, fontSize: 22,
                height: 1.16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Divider(color: dark
              ? const Color(0x30FFD2CD) : const Color(0x309A6D67),
              height: 1),
            const SizedBox(height: 10),
            LayoutBuilder(builder: (context, bounds) {
              // The HTML footer keeps expiry facts together and renew to
              // the right. On narrow devices, move only the CTA below them
              // instead of shrinking dates into clipped fragments.
              final narrow = bounds.maxWidth < 230;
              final metadata = Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v3Copy(context, zh: '到期日期',
                          en: 'Expiry date', tw: '到期日期'),
                      style: TextStyle(color: dark
                        ? const Color(0xFFCEB1AF)
                        : const Color(0xFF9E7D78), fontSize: 10)),
                    const SizedBox(height: 6),
                    Text(dateText, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                  ],
                )),
                Expanded(child: Container(
                  padding: const EdgeInsets.only(left: 11),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: dark
                      ? const Color(0x30FFD2CD)
                      : const Color(0x309A6D67)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v3Copy(context, zh: '剩余有效期',
                          en: 'Remaining time', tw: '剩餘有效期'),
                        style: TextStyle(color: dark
                          ? const Color(0xFFCEB1AF)
                          : const Color(0xFF9E7D78), fontSize: 10)),
                      const SizedBox(height: 6),
                      Text(plan.expiryKind == PlanExpiryKind.permanent
                          ? v3Copy(context, zh: '永久',
                              en: 'Permanent', tw: '永久')
                          : remaining,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ink, fontSize: 12,
                          fontWeight: FontWeight.w800)),
                    ],
                  ),
                )),
              ]);
              final action = onRenew == null ? null : SizedBox(
                height: 32,
                child: FilledButton(
                  onPressed: onRenew,
                  style: FilledButton.styleFrom(
                    backgroundColor: dark ? const Color(0xFFF3E4E1)
                      : const Color(0xFF282629),
                    foregroundColor: dark ? const Color(0xFF2D2529)
                      : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(controller.hasPlan
                      ? v3Copy(context, zh: '续费', en: 'Renew', tw: '續費')
                      : v3Copy(context, zh: '购买', en: 'Buy', tw: '購買'),
                      style: const TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 14),
                  ]),
                ),
              );
              if (action == null) return metadata;
              if (narrow) {
                return Column(crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    metadata,
                    const SizedBox(height: 12),
                    action,
                  ]);
              }
              return Row(children: [
                Expanded(child: metadata),
                const SizedBox(width: 10),
                action,
              ]);
            }),
          ]),
        ),
      ]),
      ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileInvitePage extends StatelessWidget {
  const MobileInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return RefreshIndicator(
      onRefresh: ctrl.refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          Row(
            children: [
              Expanded(child: Text('邀请', style: AppTextStyles.pageTitle.copyWith(fontSize: 26))),
              IconButton(onPressed: ctrl.refreshData, icon: Icon(LucideIcons.refreshCw, color: c.primary)),
            ],
          ),
          const SizedBox(height: 16),
          _InviteCard(title: '邀请码', value: ctrl.inviteCode.isEmpty ? '--' : ctrl.inviteCode, icon: LucideIcons.ticket),
          const SizedBox(height: 10),
          _InviteCard(title: '邀请链接', value: ctrl.inviteLink.isEmpty ? '--' : ctrl.inviteLink, icon: LucideIcons.link),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _MiniCard(title: '邀请人数', value: ctrl.invitedCount.toString())),
              const SizedBox(width: 10),
              Expanded(child: _MiniCard(title: '佣金比例', value: '${ctrl.commissionRate.toStringAsFixed(0)}%')),
            ],
          ),
          const SizedBox(height: 10),
          _InviteCard(title: '可提现佣金', value: '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}', icon: LucideIcons.wallet),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Row(
        children: [
          Icon(icon, color: c.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 4),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.bodyStrong),
      ]),
    );
  }
}

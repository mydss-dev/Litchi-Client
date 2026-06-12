import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileProfilePage extends StatelessWidget {
  const MobileProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final user = ctrl.user;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(child: Text('我的', style: AppTextStyles.pageTitle.copyWith(fontSize: 26))),
            GestureDetector(
              onTap: ctrl.refreshData,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(LucideIcons.refreshCw, color: c.primary, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: c.primarySoft,
                child: Text(user.avatarLetter.isEmpty ? 'L' : user.avatarLetter, style: AppTextStyles.bodyStrong.copyWith(color: c.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name.isEmpty ? '--' : user.name, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 3),
                    Text(user.plan.isEmpty ? '暂无套餐' : user.plan, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                    if (user.expiry.isNotEmpty) Text('到期：${user.expiry}', style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _StatCard(label: '邀请码', value: ctrl.inviteCode.isEmpty ? '--' : ctrl.inviteCode)),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '邀请人数', value: ctrl.invitedCount.toString())),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(label: '佣金比例', value: '${ctrl.commissionRate.toStringAsFixed(0)}%')),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(label: '可提现', value: '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: 14),
        _MenuTile(icon: LucideIcons.gift, title: '邀请好友', subtitle: '查看邀请码与返佣信息', onTap: () => ctrl.goToPage(AppPage.invite)),
        _MenuTile(icon: LucideIcons.clipboardList, title: '订单记录', subtitle: '查看购买记录与支付状态', onTap: () => ctrl.goToPage(AppPage.orders)),
        _MenuTile(icon: LucideIcons.messageSquare, title: '工单支持', subtitle: '联系在线客服', onTap: () => ctrl.goToPage(AppPage.tickets)),
        _MenuTile(icon: LucideIcons.settings, title: '设置', subtitle: '网络与应用设置', onTap: () => ctrl.goToPage(AppPage.settings)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.cardBg, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: c.softBorder)),
          child: Row(
            children: [
              Icon(icon, color: c.iconDefault, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

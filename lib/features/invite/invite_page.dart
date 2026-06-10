import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';

/// Invite page (§14): hero with invite code + stats + invite link.
class InvitePage extends StatelessWidget {
  const InvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '邀请好友', subtitle: '分享邀请链接获得返佣奖励'),
          const SizedBox(height: 12),
          const _InviteHero(),
          const SizedBox(height: 16),
          const _StatsGrid(),
          const SizedBox(height: 16),
          const _InviteLinkCard(),
        ],
      ),
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    return Container(
      height: 190,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        color: c.primarySoft,
      ),
      child: Row(
        children: [
          Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.cardBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Text('🎁', style: TextStyle(fontSize: 56)),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('你的专属邀请码',
                    style: AppTextStyles.body.copyWith(color: c.textMuted)),
                const SizedBox(height: 8),
                Text(ctrl.inviteCode,
                    style: AppTextStyles.largeNumber(fontSize: 34)
                        .copyWith(color: c.textPrimary)),
                const SizedBox(height: 14),
                _CopyButton(
                  label: '复制邀请码',
                  value: ctrl.inviteCode,
                  filled: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final stats = [
      (
        LucideIcons.trendingUp,
        '返佣比例',
        '${ctrl.commissionRate.toInt()}%',
        '好友消费后，你可获得返佣',
      ),
      (
        LucideIcons.users,
        '已邀请',
        '${ctrl.invitedCount} 人',
        '累计获得奖励',
      ),
      (
        LucideIcons.wallet,
        '可提现',
        '¥${ctrl.withdrawable.toStringAsFixed(2)}',
        '可随时提现到账户余额',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 560 ? 3 : 1;
        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            mainAxisExtent: 120,
          ),
          itemBuilder: (context, i) {
            final (icon, label, value, hint) = stats[i];
            return _StatCard(icon: icon, label: label, value: value, hint: hint);
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: AppTextStyles.largeNumber(fontSize: 24).copyWith(color: c.primary)),
          const Spacer(),
          Text(hint,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('邀请链接',
              style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(ctrl.inviteLink,
                      style: AppTextStyles.body.copyWith(color: c.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 12),
              _CopyButton(label: '复制链接', value: ctrl.inviteLink),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({
    required this.label,
    required this.value,
    this.filled = false,
  });

  final String label;
  final String value;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) {
            AppToast.show(context, '已复制', type: AppToastType.success);
          }
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: filled ? c.primary : c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.copy,
                  size: 15, color: filled ? Colors.white : c.primary),
              const SizedBox(width: 8),
              Text(label,
                  style: AppTextStyles.button.copyWith(
                    color: filled ? Colors.white : c.primary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

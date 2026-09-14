import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/models/api_models.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_icon_button.dart';

class GreenfieldInviteSurface extends StatelessWidget {
  const GreenfieldInviteSurface({
    super.key,
    required this.invite,
    required this.selectedIndex,
    required this.inviteCount,
    required this.creating,
    required this.registeredUsers,
    required this.pendingCommission,
    required this.earnedCommission,
    required this.commissionRate,
    required this.records,
    required this.currencySymbol,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    required this.onCopy,
    required this.onShareWechat,
    required this.onShareQq,
    required this.onShareTwitter,
    required this.onShareTelegram,
  });

  final InviteCodeModel invite;
  final int selectedIndex;
  final int inviteCount;
  final bool creating;
  final int registeredUsers;
  final String pendingCommission;
  final String earnedCommission;
  final String commissionRate;
  final List<RemoteInviteRecord> records;
  final String currencySymbol;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreate;
  final VoidCallback onCopy;
  final VoidCallback onShareWechat;
  final VoidCallback onShareQq;
  final VoidCallback onShareTwitter;
  final VoidCallback onShareTelegram;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final hero = _InviteHero(
          compact: compact,
          invite: invite,
          selectedIndex: selectedIndex,
          inviteCount: inviteCount,
          creating: creating,
          onPrevious: onPrevious,
          onNext: onNext,
          onCreate: onCreate,
          onCopy: onCopy,
          onShareWechat: onShareWechat,
          onShareQq: onShareQq,
          onShareTwitter: onShareTwitter,
          onShareTelegram: onShareTelegram,
        );
        final stats = _InviteStats(
          compact: compact,
          registeredUsers: registeredUsers,
          pendingCommission: pendingCommission,
          earnedCommission: earnedCommission,
          commissionRate: commissionRate,
        );
        final history = _CommissionHistory(
          records: records,
          currencySymbol: currencySymbol,
        );

        return Column(
          key: const ValueKey('greenfield-invite-surface'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: AppSpacing.lg),
            stats,
            const SizedBox(height: AppSpacing.lg),
            history,
            if (compact) const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _InviteHero extends StatelessWidget {
  const _InviteHero({
    required this.compact,
    required this.invite,
    required this.selectedIndex,
    required this.inviteCount,
    required this.creating,
    required this.onPrevious,
    required this.onNext,
    required this.onCreate,
    required this.onCopy,
    required this.onShareWechat,
    required this.onShareQq,
    required this.onShareTwitter,
    required this.onShareTelegram,
  });

  final bool compact;
  final InviteCodeModel invite;
  final int selectedIndex;
  final int inviteCount;
  final bool creating;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onCreate;
  final VoidCallback onCopy;
  final VoidCallback onShareWechat;
  final VoidCallback onShareQq;
  final VoidCallback onShareTwitter;
  final VoidCallback onShareTelegram;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final hasMany = inviteCount > 1;
    final code = invite.code.trim().isEmpty ? '--' : invite.code.trim();
    final link = invite.link.trim();

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      color: c.primarySoft.withValues(alpha: 0.46),
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  LucideIcons.userPlus,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.inviteFriends,
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.l10n.inviteSubtitle,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: AppSpacing.md),
                AppButton(
                  label: creating
                      ? context.l10n.creating
                      : context.l10n.createInviteCode,
                  leadingIcon: LucideIcons.plus,
                  variant: AppButtonVariant.secondary,
                  size: AppControlSize.compact,
                  loading: creating,
                  onPressed: creating ? null : onCreate,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              if (hasMany)
                AppIconButton(
                  icon: LucideIcons.chevronLeft,
                  onPressed: onPrevious,
                  variant: AppIconButtonVariant.surface,
                  tooltip: context.l10n.inviteCodeIndex(selectedIndex + 1),
                ),
              if (hasMany) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? AppSpacing.md : AppSpacing.xl,
                    vertical: compact ? AppSpacing.lg : AppSpacing.xl,
                  ),
                  decoration: BoxDecoration(
                    color: c.cardBg.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: c.softBorder),
                  ),
                  child: Column(
                    children: [
                      Text(
                        context.l10n.inviteCodeIndex(selectedIndex + 1),
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.largeNumber(
                          fontSize: compact ? 28 : 34,
                        ).copyWith(color: c.textPrimary),
                      ),
                      if (hasMany) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${selectedIndex + 1} / $inviteCount',
                          style: AppTextStyles.caption.copyWith(
                            color: c.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (hasMany) const SizedBox(width: AppSpacing.sm),
              if (hasMany)
                AppIconButton(
                  icon: LucideIcons.chevronRight,
                  onPressed: onNext,
                  variant: AppIconButtonVariant.surface,
                  tooltip: context.l10n.inviteCodeIndex(selectedIndex + 1),
                ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: creating
                  ? context.l10n.creating
                  : context.l10n.createInviteCode,
              leadingIcon: LucideIcons.plus,
              variant: AppButtonVariant.secondary,
              loading: creating,
              onPressed: creating ? null : onCreate,
              expand: true,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Container(
            minHeight: 48,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.link, size: 16, color: c.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    link.isEmpty ? context.l10n.inviteLinkUnavailable : link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: link.isEmpty ? c.textMuted : c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: context.l10n.copyLink,
                  leadingIcon: LucideIcons.copy,
                  size: AppControlSize.compact,
                  onPressed: onCopy,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: context.l10n.wechat,
                leadingIcon: LucideIcons.messageCircle,
                variant: AppButtonVariant.outline,
                size: AppControlSize.compact,
                onPressed: onShareWechat,
              ),
              AppButton(
                label: 'QQ',
                leadingIcon: LucideIcons.messageCircleMore,
                variant: AppButtonVariant.outline,
                size: AppControlSize.compact,
                onPressed: onShareQq,
              ),
              AppButton(
                label: 'Twitter',
                leadingIcon: LucideIcons.share2,
                variant: AppButtonVariant.outline,
                size: AppControlSize.compact,
                onPressed: onShareTwitter,
              ),
              AppButton(
                label: 'Telegram',
                leadingIcon: LucideIcons.send,
                variant: AppButtonVariant.outline,
                size: AppControlSize.compact,
                onPressed: onShareTelegram,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteStats extends StatelessWidget {
  const _InviteStats({
    required this.compact,
    required this.registeredUsers,
    required this.pendingCommission,
    required this.earnedCommission,
    required this.commissionRate,
  });

  final bool compact;
  final int registeredUsers;
  final String pendingCommission;
  final String earnedCommission;
  final String commissionRate;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatData(
        icon: LucideIcons.users,
        label: context.l10n.registeredUsers,
        value: context.l10n.peopleCount(registeredUsers),
      ),
      _StatData(
        icon: LucideIcons.circleDollarSign,
        label: context.l10n.pendingCommission,
        value: pendingCommission,
      ),
      _StatData(
        icon: LucideIcons.walletCards,
        label: context.l10n.totalCommission,
        value: earnedCommission,
      ),
      _StatData(
        icon: LucideIcons.chartNoAxesColumnIncreasing,
        label: context.l10n.commissionRate,
        value: commissionRate,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact ? 2 : 4;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _StatCard(data: item)),
          ],
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(data.icon, size: 17, color: c.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong.copyWith(
              color: c.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CommissionHistory extends StatelessWidget {
  const _CommissionHistory({
    required this.records,
    required this.currencySymbol,
  });

  final List<RemoteInviteRecord> records;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final visible = records.take(10).toList(growable: false);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receiptText, size: 18, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.commissionRecords,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                context.l10n.noCommissionRecords,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              _RecordRow(
                record: visible[index],
                currencySymbol: currencySymbol,
              ),
              if (index != visible.length - 1)
                Divider(height: AppSpacing.xl, color: c.softBorder),
            ],
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.record,
    required this.currencySymbol,
  });

  final RemoteInviteRecord record;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final userName = record.userName.trim().isEmpty
        ? context.l10n.invitedUser
        : record.userName.trim();
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(LucideIcons.coins, size: 17, color: c.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                context.l10n.recordOrderAmount(
                  record.dateDisplay,
                  record.amountDisplay(currencySymbol),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          '+${record.commissionDisplay(currencySymbol)}',
          style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
        ),
      ],
    );
  }
}

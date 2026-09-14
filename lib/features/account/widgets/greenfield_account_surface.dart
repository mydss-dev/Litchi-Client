import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/layout/app_platform.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_switch.dart';

class GreenfieldAccountSurface extends StatelessWidget {
  const GreenfieldAccountSurface({
    super.key,
    required this.userName,
    required this.avatarLetter,
    required this.hasPlan,
    required this.planName,
    required this.expiryLabel,
    required this.balanceText,
    required this.commissionText,
    required this.showGiftCard,
    required this.showTelegram,
    required this.telegramBound,
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onPlanAction,
    required this.onWallet,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
    required this.onOrders,
    required this.onTraffic,
    required this.onInvite,
    required this.onGiftCard,
    required this.onTelegram,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

  final String userName;
  final String avatarLetter;
  final bool hasPlan;
  final String planName;
  final String expiryLabel;
  final String balanceText;
  final String commissionText;
  final bool showGiftCard;
  final bool showTelegram;
  final bool telegramBound;
  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;

  final VoidCallback onPlanAction;
  final VoidCallback onWallet;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;
  final VoidCallback onOrders;
  final VoidCallback onTraffic;
  final VoidCallback onInvite;
  final VoidCallback onGiftCard;
  final VoidCallback onTelegram;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = AppPlatform.usesTouch || constraints.maxWidth < 600;
        return Column(
          key: const ValueKey('greenfield-account-surface'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfilePlanHero(
              compact: compact,
              userName: userName,
              avatarLetter: avatarLetter,
              hasPlan: hasPlan,
              planName: planName,
              expiryLabel: expiryLabel,
              onPlanAction: onPlanAction,
            ),
            const SizedBox(height: AppSpacing.lg),
            _WalletOverview(
              compact: compact,
              balanceText: balanceText,
              commissionText: commissionText,
              onWallet: onWallet,
              onRecharge: onRecharge,
              onTransfer: onTransfer,
              onWithdraw: onWithdraw,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ServicesSection(
              compact: compact,
              showGiftCard: showGiftCard,
              showTelegram: showTelegram,
              telegramBound: telegramBound,
              onOrders: onOrders,
              onTraffic: onTraffic,
              onInvite: onInvite,
              onGiftCard: onGiftCard,
              onTelegram: onTelegram,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SecuritySection(
              hasPlan: hasPlan,
              remindExpire: remindExpire,
              remindTraffic: remindTraffic,
              autoRenewal: autoRenewal,
              onExpireChanged: onExpireChanged,
              onTrafficChanged: onTrafficChanged,
              onAutoRenewalChanged: onAutoRenewalChanged,
              onChangePassword: onChangePassword,
              onLogout: onLogout,
            ),
            if (compact) const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    );
  }
}

class _ProfilePlanHero extends StatelessWidget {
  const _ProfilePlanHero({
    required this.compact,
    required this.userName,
    required this.avatarLetter,
    required this.hasPlan,
    required this.planName,
    required this.expiryLabel,
    required this.onPlanAction,
  });

  final bool compact;
  final String userName;
  final String avatarLetter;
  final bool hasPlan;
  final String planName;
  final String expiryLabel;
  final VoidCallback onPlanAction;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final avatar = Container(
      width: compact ? 58 : 68,
      height: compact ? 58 : 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        avatarLetter.isEmpty ? 'L' : avatarLetter.characters.first,
        style: AppTextStyles.heroTitle.copyWith(color: Colors.white),
      ),
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userName.isEmpty ? context.l10n.account : userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasPlan ? LucideIcons.crown : LucideIcons.circleUserRound,
              size: 14,
              color: hasPlan ? c.primary : c.textMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                hasPlan ? planName : context.l10n.noPlan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: hasPlan ? c.primary : c.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          expiryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
      ],
    );

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      color: c.primarySoft.withValues(alpha: 0.48),
      borderColor: c.primary.withValues(alpha: 0.14),
      shadow: AppCardShadow.soft,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: identity),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: hasPlan ? context.l10n.renewPlan : context.l10n.buyPlans,
                  leadingIcon: hasPlan ? LucideIcons.refreshCw : LucideIcons.sparkles,
                  onPressed: onPlanAction,
                  expand: true,
                ),
              ],
            )
          : Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.lg),
                AppButton(
                  label: hasPlan ? context.l10n.renewPlan : context.l10n.buyPlans,
                  leadingIcon: hasPlan ? LucideIcons.refreshCw : LucideIcons.sparkles,
                  onPressed: onPlanAction,
                ),
              ],
            ),
    );
  }
}

class _WalletOverview extends StatelessWidget {
  const _WalletOverview({
    required this.compact,
    required this.balanceText,
    required this.commissionText,
    required this.onWallet,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final bool compact;
  final String balanceText;
  final String commissionText;
  final VoidCallback onWallet;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(LucideIcons.walletCards, size: 18, color: c.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.accountAssets,
                  style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
                ),
              ),
              TextButton(onPressed: onWallet, child: Text(context.l10n.wallet)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _MoneyMetric(
                  label: context.l10n.accountBalance,
                  value: balanceText,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: _MoneyMetric(
                  label: context.l10n.withdrawableCommission,
                  value: commissionText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: context.l10n.rechargeBalance,
                leadingIcon: LucideIcons.circlePlus,
                onPressed: onRecharge,
                size: AppControlSize.compact,
              ),
              AppButton(
                label: context.l10n.transferCommission,
                leadingIcon: LucideIcons.arrowLeftRight,
                variant: AppButtonVariant.secondary,
                onPressed: onTransfer,
                size: AppControlSize.compact,
              ),
              AppButton(
                label: context.l10n.requestWithdrawal,
                leadingIcon: LucideIcons.banknoteArrowUp,
                variant: AppButtonVariant.outline,
                onPressed: onWithdraw,
                size: AppControlSize.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyMetric extends StatelessWidget {
  const _MoneyMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.largeNumber(fontSize: 22).copyWith(color: c.textPrimary),
        ),
      ],
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.compact,
    required this.showGiftCard,
    required this.showTelegram,
    required this.telegramBound,
    required this.onOrders,
    required this.onTraffic,
    required this.onInvite,
    required this.onGiftCard,
    required this.onTelegram,
  });

  final bool compact;
  final bool showGiftCard;
  final bool showTelegram;
  final bool telegramBound;
  final VoidCallback onOrders;
  final VoidCallback onTraffic;
  final VoidCallback onInvite;
  final VoidCallback onGiftCard;
  final VoidCallback onTelegram;

  @override
  Widget build(BuildContext context) {
    final items = <_ServiceItem>[
      _ServiceItem(
        icon: LucideIcons.clipboardList,
        title: context.l10n.orders,
        subtitle: context.l10n.ordersSubtitle,
        onTap: onOrders,
      ),
      _ServiceItem(
        icon: LucideIcons.chartNoAxesCombined,
        title: context.l10n.usage,
        subtitle: context.l10n.usageSubtitle,
        onTap: onTraffic,
      ),
      _ServiceItem(
        icon: LucideIcons.usersRound,
        title: context.l10n.invite,
        subtitle: context.l10n.inviteSubtitle,
        onTap: onInvite,
      ),
      if (showGiftCard)
        _ServiceItem(
          icon: LucideIcons.ticketCheck,
          title: context.l10n.giftCardTitle,
          subtitle: context.l10n.giftCardServiceSubtitle,
          onTap: onGiftCard,
        ),
      if (showTelegram)
        _ServiceItem(
          icon: LucideIcons.send,
          title: 'Telegram',
          subtitle: telegramBound
              ? context.l10n.telegramServiceConnected
              : context.l10n.telegramServiceNotConnected,
          onTap: onTelegram,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.accountServices, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = compact ? 1 : 2;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in items)
                  SizedBox(width: width, child: _ServiceTile(item: item)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.item});

  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      onTap: item.onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      shadow: AppCardShadow.none,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(item.icon, size: 18, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(LucideIcons.chevronRight, size: 16, color: c.iconMuted),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.hasPlan,
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

  final bool hasPlan;
  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.accountSettings, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              if (hasPlan) ...[
                _SettingSwitchRow(
                  icon: LucideIcons.calendarClock,
                  title: context.l10n.expiryReminder,
                  subtitle: context.l10n.expiryReminderSubtitle,
                  value: remindExpire,
                  onChanged: onExpireChanged,
                ),
                const Divider(height: AppSpacing.xl),
                _SettingSwitchRow(
                  icon: LucideIcons.gauge,
                  title: context.l10n.trafficReminder,
                  subtitle: context.l10n.trafficReminderSubtitle,
                  value: remindTraffic,
                  onChanged: onTrafficChanged,
                ),
                const Divider(height: AppSpacing.xl),
                _SettingSwitchRow(
                  icon: LucideIcons.refreshCw,
                  title: context.l10n.autoRenewal,
                  subtitle: context.l10n.autoRenewalSubtitle,
                  value: autoRenewal,
                  onChanged: onAutoRenewalChanged,
                ),
                const Divider(height: AppSpacing.xl),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: context.l10n.changePasswordTitle,
                      leadingIcon: LucideIcons.lockKeyhole,
                      variant: AppButtonVariant.secondary,
                      onPressed: onChangePassword,
                      expand: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: context.l10n.logout,
                      leadingIcon: LucideIcons.logOut,
                      variant: AppButtonVariant.danger,
                      onPressed: onLogout,
                      expand: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSwitchRow extends StatelessWidget {
  const _SettingSwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: c.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        AppSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

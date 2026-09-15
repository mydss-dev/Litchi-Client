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
    required this.showOrders,
    required this.showTraffic,
    required this.showInvite,
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
  final bool showOrders;
  final bool showTraffic;
  final bool showInvite;
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
            _AccountHub(
              compact: compact,
              userName: userName,
              avatarLetter: avatarLetter,
              hasPlan: hasPlan,
              planName: planName,
              expiryLabel: expiryLabel,
              balanceText: balanceText,
              commissionText: commissionText,
              onPlanAction: onPlanAction,
              onWallet: onWallet,
              onRecharge: onRecharge,
              onTransfer: onTransfer,
              onWithdraw: onWithdraw,
            ),
            if (showOrders || showTraffic || showInvite || showGiftCard || showTelegram) ...[
              const SizedBox(height: AppSpacing.xl),
              _ServiceLauncher(
                compact: compact,
                showOrders: showOrders,
                showTraffic: showTraffic,
                showInvite: showInvite,
                showGiftCard: showGiftCard,
                showTelegram: showTelegram,
                telegramBound: telegramBound,
                onOrders: onOrders,
                onTraffic: onTraffic,
                onInvite: onInvite,
                onGiftCard: onGiftCard,
                onTelegram: onTelegram,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            _AccountPreferences(
              compact: compact,
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

class _AccountHub extends StatelessWidget {
  const _AccountHub({
    required this.compact,
    required this.userName,
    required this.avatarLetter,
    required this.hasPlan,
    required this.planName,
    required this.expiryLabel,
    required this.balanceText,
    required this.commissionText,
    required this.onPlanAction,
    required this.onWallet,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final bool compact;
  final String userName;
  final String avatarLetter;
  final bool hasPlan;
  final String planName;
  final String expiryLabel;
  final String balanceText;
  final String commissionText;
  final VoidCallback onPlanAction;
  final VoidCallback onWallet;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final identity = _IdentityBlock(
      compact: compact,
      userName: userName,
      avatarLetter: avatarLetter,
      hasPlan: hasPlan,
      planName: planName,
      expiryLabel: expiryLabel,
      onPlanAction: onPlanAction,
    );
    final assets = _AssetBlock(
      balanceText: balanceText,
      commissionText: commissionText,
      onWallet: onWallet,
      onRecharge: onRecharge,
      onTransfer: onTransfer,
      onWithdraw: onWithdraw,
    );

    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xl),
      color: c.cardBg,
      borderColor: c.softBorder,
      shadow: AppCardShadow.soft,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(height: 1, color: c.softBorder),
                ),
                assets,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: identity),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  color: c.softBorder,
                ),
                Expanded(flex: 6, child: assets),
              ],
            ),
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
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
      width: compact ? 54 : 62,
      height: compact ? 54 : 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        avatarLetter.isEmpty ? 'L' : avatarLetter,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: AppTextStyles.heroTitle.copyWith(color: Colors.white),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            avatar,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
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
                    children: [
                      Icon(
                        hasPlan ? LucideIcons.crown : LucideIcons.user,
                        size: 14,
                        color: hasPlan ? c.primary : c.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          hasPlan ? planName : context.l10n.noCurrentPlan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: hasPlan ? c.primary : c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          expiryLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: hasPlan ? context.l10n.renewPlan : context.l10n.buyPlans,
          leadingIcon: hasPlan ? LucideIcons.refreshCw : LucideIcons.plus,
          onPressed: onPlanAction,
          size: AppControlSize.compact,
          expand: compact,
        ),
      ],
    );
  }
}

class _AssetBlock extends StatelessWidget {
  const _AssetBlock({
    required this.balanceText,
    required this.commissionText,
    required this.onWallet,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String balanceText;
  final String commissionText;
  final VoidCallback onWallet;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Icon(LucideIcons.wallet, size: 17, color: c.primary),
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
              leadingIcon: LucideIcons.plus,
              onPressed: onRecharge,
              size: AppControlSize.compact,
            ),
            AppButton(
              label: context.l10n.transferCommission,
              leadingIcon: LucideIcons.badgeDollarSign,
              variant: AppButtonVariant.secondary,
              onPressed: onTransfer,
              size: AppControlSize.compact,
            ),
            AppButton(
              label: context.l10n.requestWithdrawal,
              leadingIcon: LucideIcons.wallet,
              variant: AppButtonVariant.outline,
              onPressed: onWithdraw,
              size: AppControlSize.compact,
            ),
          ],
        ),
      ],
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

class _ServiceLauncher extends StatelessWidget {
  const _ServiceLauncher({
    required this.compact,
    required this.showOrders,
    required this.showTraffic,
    required this.showInvite,
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
  final bool showOrders;
  final bool showTraffic;
  final bool showInvite;
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
    final items = <_LauncherItem>[
      if (showOrders)
        _LauncherItem(
          icon: LucideIcons.clipboardList,
          title: context.l10n.orders,
          subtitle: context.l10n.ordersSubtitle,
          onTap: onOrders,
        ),
      if (showTraffic)
        _LauncherItem(
          icon: LucideIcons.chartColumn,
          title: context.l10n.usage,
          subtitle: context.l10n.usageSubtitle,
          onTap: onTraffic,
        ),
      if (showInvite)
        _LauncherItem(
          icon: LucideIcons.gift,
          title: context.l10n.invite,
          subtitle: context.l10n.inviteSubtitle,
          onTap: onInvite,
        ),
      if (showGiftCard)
        _LauncherItem(
          icon: LucideIcons.ticketCheck,
          title: context.l10n.giftCardTitle,
          subtitle: context.l10n.giftCardServiceSubtitle,
          onTap: onGiftCard,
        ),
      if (showTelegram)
        _LauncherItem(
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
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = compact ? 3 : items.length.clamp(3, 5);
            final spacing = compact ? AppSpacing.xs : AppSpacing.sm;
            final width = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in items)
                  SizedBox(
                    width: width,
                    child: _LauncherTile(item: item, compact: compact),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LauncherItem {
  const _LauncherItem({
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

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.item, required this.compact});

  final _LauncherItem item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.xs : AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 42 : 46,
                height: compact ? 42 : 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(item.icon, size: 19, color: c.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
              ),
              if (!compact) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountPreferences extends StatelessWidget {
  const _AccountPreferences({
    required this.compact,
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

  final bool compact;
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
        Text(context.l10n.accountManagement, style: AppTextStyles.sectionTitle),
        const SizedBox(height: AppSpacing.sm),
        if (hasPlan) ...[
          _PreferenceRow(
            icon: LucideIcons.calendarClock,
            title: context.l10n.expiryReminder,
            subtitle: context.l10n.expiryReminderSubtitle,
            value: remindExpire,
            onChanged: onExpireChanged,
          ),
          Divider(height: 1, color: c.softBorder),
          _PreferenceRow(
            icon: LucideIcons.gauge,
            title: context.l10n.trafficReminder,
            subtitle: context.l10n.trafficReminderSubtitle,
            value: remindTraffic,
            onChanged: onTrafficChanged,
          ),
          Divider(height: 1, color: c.softBorder),
          _PreferenceRow(
            icon: LucideIcons.refreshCw,
            title: context.l10n.autoRenewal,
            subtitle: context.l10n.autoRenewalSubtitle,
            value: autoRenewal,
            onChanged: onAutoRenewalChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppButton(
                label: context.l10n.changePasswordTitle,
                leadingIcon: LucideIcons.lockKeyhole,
                variant: AppButtonVariant.secondary,
                onPressed: onChangePassword,
                expand: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: context.l10n.logout,
                leadingIcon: LucideIcons.logOut,
                variant: AppButtonVariant.danger,
                onPressed: onLogout,
                expand: true,
              ),
            ],
          )
        else
          Row(
            children: [
              AppButton(
                label: context.l10n.changePasswordTitle,
                leadingIcon: LucideIcons.lockKeyhole,
                variant: AppButtonVariant.secondary,
                onPressed: onChangePassword,
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: context.l10n.logout,
                leadingIcon: LucideIcons.logOut,
                variant: AppButtonVariant.danger,
                onPressed: onLogout,
              ),
            ],
          ),
      ],
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 17, color: c.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

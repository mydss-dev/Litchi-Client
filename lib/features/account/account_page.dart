import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../app/nav_destinations.dart';
import '../shop/order_confirm_dialog.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/brand_asset_cache.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/no_plan_card.dart';

/// Account / Profile — the mobile profile page.
///
/// Pull-to-refresh, profile header, menu section, and settings/password/logout
/// bottom sheets.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _updating = false;

  // ── Compact-branch handlers (settings / password / logout sheets) ──────
  Future<void> _updateSettings({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updating) return;
    final ctrl = AppScope.of(context);
    _updating = true;
    final error = await ctrl.updateUserSettings(
      remindExpire: remindExpire ?? ctrl.user.remindExpire,
      remindTraffic: remindTraffic ?? ctrl.user.remindTraffic,
      autoRenewal: autoRenewal ?? ctrl.user.autoRenewal,
    );
    if (!mounted) return;
    _updating = false;
    AppToast.show(
      context,
      error ?? context.l10n.settingsUpdated,
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  void _showAccountSheet() {
    final ctrl = AppScope.of(context);
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) => _AccountManageSheet(
          hasPlan: ctrl.hasPlan,
          remindExpire: ctrl.user.remindExpire,
          remindTraffic: ctrl.user.remindTraffic,
          autoRenewal: ctrl.user.autoRenewal,
          onExpireChanged: (value) => _updateSettings(remindExpire: value),
          onTrafficChanged: (value) => _updateSettings(remindTraffic: value),
          onAutoRenewalChanged: (value) => _updateSettings(autoRenewal: value),
          onChangePassword: () {
            Navigator.of(context).pop();
            _showChangePasswordSheet();
          },
          onLogout: () {
            Navigator.of(context).pop();
            _confirmLogout();
          },
        ),
      ),
    );
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  Future<void> _renewCurrentPlan() async {
    final ctrl = AppScope.of(context);
    final currentPlanId = ctrl.currentPlanId;
    PlanModel? currentPlan;
    if (currentPlanId != null) {
      for (final plan in ctrl.plans) {
        if (int.tryParse(plan.id) == currentPlanId) {
          currentPlan = plan;
          break;
        }
      }
    }

    if (currentPlan == null) {
      ctrl.goToPage(AppPage.shop);
      return;
    }

    final plan = currentPlan;
    var cycle = BillingCycle.monthly;
    if (plan.category == PlanCategory.recurring) {
      for (final candidate in BillingCycle.values) {
        if (plan.priceForCycle(candidate) != null) {
          cycle = candidate;
          break;
        }
      }
    }

    await showOrderConfirmDialog(
      context: context,
      plan: plan,
      cycle: cycle,
      api: ctrl.api,
      onPaid: ctrl.refreshData,
    );
  }

  void _showChangePasswordSheet() {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const _LogoutSheet(),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    if (CorePlatformSupport.isDesktop) return _buildDesktop(context);
    return _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final canRenew = isPageEnabled(AppPage.shop) && ctrl.hasPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.myAccount,
                    style: AppTextStyles.pageTitle.copyWith(
                      color: c.textPrimary,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.l10n.myAccountSubtitle,
                    style: AppTextStyles.body.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Tooltip(
              message: context.l10n.refresh,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handlePullRefresh,
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Ink(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: c.softBorder),
                    ),
                    child: Icon(
                      LucideIcons.refreshCw,
                      size: 17,
                      color: c.iconDefault,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ProfileHeader(
          userName: user.name,
          plan: user.plan,
          expiry: user.expiry,
          avatar: user.avatarLetter,
          hidePlan: false,
          hideExpiry: false,
          onRenew: canRenew ? _renewCurrentPlan : null,
          onManage: _showAccountSheet,
        ),
        const SizedBox(height: 14),
        if (!ctrl.hasPlan)
          NoPlanCard(
            onPurchase: isPageEnabled(AppPage.shop)
                ? () => ctrl.goToPage(AppPage.shop)
                : null,
          )
        else ...[
          _DesktopAccountMetrics(ctrl: ctrl),
          const SizedBox(height: 14),
          _TrafficOverviewCard(
            usedGb: ctrl.traffic.usedGb,
            totalGb: ctrl.traffic.totalGb,
            remainGb: ctrl.traffic.remainGb,
            resetDay: ctrl.resetDay,
          ),
        ],
        const SizedBox(height: 16),
        _DesktopProfileMenuSection(ctrl: ctrl),
      ],
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    const summaryType = 'traffic';
    final canRenew = isPageEnabled(AppPage.shop) && ctrl.hasPlan;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            userName: user.name,
            plan: user.plan,
            expiry: user.expiry,
            avatar: user.avatarLetter,
            hidePlan: _isPlanSummary(summaryType),
            hideExpiry: _isExpireSummary(summaryType),
            onRenew: canRenew ? _renewCurrentPlan : null,
            onManage: _showAccountSheet,
          ),
          const SizedBox(height: 12),
          _ProfileSummaryCard(type: summaryType, ctrl: ctrl),
          const SizedBox(height: 14),
          _ProfileMenuSection(ctrl: ctrl),
        ],
      ),
    );
  }
}


// ── Desktop account widgets ──────────────────────────────────────────────

class _DesktopAccountMetrics extends StatelessWidget {
  const _DesktopAccountMetrics({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * 2) / 3;
        final balance = ctrl.user.balance / 100;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _DesktopAccountMetric(
                icon: LucideIcons.package,
                label: context.l10n.currentPlan,
                value: ctrl.user.plan.isEmpty
                    ? context.l10n.noCurrentPlan
                    : ctrl.user.plan,
              ),
            ),
            SizedBox(
              width: width,
              child: _DesktopAccountMetric(
                icon: LucideIcons.wallet,
                label: context.l10n.accountBalance,
                value:
                    '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
              ),
            ),
            SizedBox(
              width: width,
              child: _DesktopAccountMetric(
                icon: LucideIcons.calendarClock,
                label: context.l10n.expiryTime,
                value: ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DesktopAccountMetric extends StatelessWidget {
  const _DesktopAccountMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      height: 96,
      padding: const EdgeInsets.all(14),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          _SmallIcon(icon: icon, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopProfileMenuSection extends StatelessWidget {
  const _DesktopProfileMenuSection({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 820 ? 4 : 3;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in hubDestinations)
              SizedBox(
                width: width,
                child: _DesktopQuickTile(
                  icon: item.icon,
                  title: item.labelFor(context),
                  subtitle: item.subtitleFor(context),
                  onTap: () => ctrl.goToPage(item.page),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DesktopQuickTile extends StatelessWidget {
  const _DesktopQuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AppCard(
        onTap: onTap,
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shadow: AppCardShadow.soft,
        child: Row(
          children: [
            _SmallIcon(icon: icon, color: c.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight, size: 16, color: c.iconMuted),
          ],
        ),
      ),
    );
  }
}

// ── Compact-layout widgets + helpers (original MobileProfilePage, verbatim)

class _TrafficOverviewCard extends StatelessWidget {
  const _TrafficOverviewCard({
    required this.usedGb,
    required this.totalGb,
    required this.remainGb,
    required this.resetDay,
  });

  final double usedGb;
  final double totalGb;
  final double remainGb;
  final int? resetDay;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final progress = totalGb <= 0 ? 0.0 : (usedGb / totalGb).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(0);
    final hasResetDay = resetDay != null && resetDay! > 0;

    return AppCard(
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SmallIcon(icon: LucideIcons.gauge, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.trafficOverview,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              Text(
                context.l10n.usedPercent(percent),
                style: AppTextStyles.caption.copyWith(
                  color: c.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${remainGb.toStringAsFixed(1)} GB',
                style: AppTextStyles.largeNumber(
                  fontSize: 24,
                ).copyWith(color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  context.l10n.remaining,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: c.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.85 ? c.warning : c.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.usedTraffic(
                    usedGb.toStringAsFixed(1),
                    totalGb.toStringAsFixed(1),
                  ),
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
              if (hasResetDay)
                Text(
                  context.l10n.monthlyResetDay(resetDay!),
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.type, required this.ctrl});

  final String type;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    if (!ctrl.hasPlan) {
      return NoPlanCard(
        onPurchase: isPageEnabled(AppPage.shop)
            ? () => ctrl.goToPage(AppPage.shop)
            : null,
      );
    }
    if (_isPlanSummary(type)) {
      return _InfoSummaryCard(
        icon: LucideIcons.package,
        title: context.l10n.currentPlan,
        value: ctrl.user.plan.isEmpty
            ? context.l10n.noCurrentPlan
            : ctrl.user.plan,
      );
    }

    if (_isExpireSummary(type)) {
      return _InfoSummaryCard(
        icon: LucideIcons.calendarClock,
        title: context.l10n.expiryTime,
        value: ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
      );
    }

    return _TrafficOverviewCard(
      usedGb: ctrl.traffic.usedGb,
      totalGb: ctrl.traffic.totalGb,
      remainGb: ctrl.traffic.remainGb,
      resetDay: ctrl.resetDay,
    );
  }
}

class _InfoSummaryCard extends StatelessWidget {
  const _InfoSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          _SmallIcon(icon: icon, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isPlanSummary(String type) {
  return type == 'plan' || type == 'currentPlan';
}

bool _isExpireSummary(String type) {
  return type == 'expire' || type == 'expireDate';
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: context.l10n.logout,
      subtitle: context.l10n.logoutDataNotice,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: c.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.logoutConfirmMessage,
                  style: AppTextStyles.caption.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.cancel),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: c.danger),
                  child: Text(context.l10n.confirmLogout),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userName,
    required this.plan,
    required this.expiry,
    required this.avatar,
    required this.hidePlan,
    required this.hideExpiry,
    this.onRenew,
    required this.onManage,
  });

  final String userName;
  final String plan;
  final String expiry;
  final String avatar;
  final bool hidePlan;
  final bool hideExpiry;
  final VoidCallback? onRenew;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      shadow: AppCardShadow.soft,
      child: Row(
        children: [
          _ProfileAvatar(avatar: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isEmpty ? '--' : userName,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                if (!hidePlan)
                  Text(
                    context.l10n.currentPlanValue(
                      plan.isEmpty ? context.l10n.noCurrentPlan : plan,
                    ),
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                if (!hideExpiry && expiry.isNotEmpty)
                  Text(
                    context.l10n.expiryValue(expiry),
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRenew != null) ...[
                _ProfileActionButton(
                  icon: LucideIcons.shoppingCart,
                  label: context.l10n.renewPlan,
                  onTap: onRenew!,
                  filled: true,
                ),
                const SizedBox(width: 6),
              ],
              _ProfileActionButton(
                icon: LucideIcons.slidersHorizontal,
                label: context.l10n.manage,
                onTap: onManage,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  const _ProfileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final foreground = filled ? Colors.white : c.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? c.primary : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: filled ? c.primary : c.primary.withValues(alpha: 0.20),
            ),
            boxShadow: AppShadows.soft(c),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatar});

  final String avatar;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final file = BrandAssetCache.avatarFile;
    final fallback = Text(
      avatar.isEmpty ? 'L' : avatar,
      style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
    );

    if (BrandAssetCache.avatarUrl.isEmpty || file == null) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: c.primarySoft,
        child: fallback,
      );
    }

    return ClipOval(
      child: Image.file(
        file,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

class _ProfileMenuSection extends StatelessWidget {
  const _ProfileMenuSection({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.58,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final item in hubDestinations)
          _MenuTile(
            icon: item.icon,
            title: item.labelFor(context),
            subtitle: item.subtitleFor(context),
            onTap: () => ctrl.goToProfileChildPage(item.page),
          ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: c.primary, size: 19),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AccountManageSheet extends StatelessWidget {
  const _AccountManageSheet({
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
    return AppBottomSheet(
      title: context.l10n.accountManagement,
      children: [
        if (hasPlan) ...[
          _SwitchRow(
            icon: LucideIcons.calendarClock,
            title: context.l10n.expiryReminder,
            subtitle: context.l10n.expiryReminderSubtitle,
            value: remindExpire,
            onChanged: onExpireChanged,
          ),
          _Divider(color: c.softBorder),
          _SwitchRow(
            icon: LucideIcons.gauge,
            title: context.l10n.trafficReminder,
            subtitle: context.l10n.trafficReminderSubtitle,
            value: remindTraffic,
            onChanged: onTrafficChanged,
          ),
          _Divider(color: c.softBorder),
          _SwitchRow(
            icon: LucideIcons.refreshCw,
            title: context.l10n.autoRenewal,
            subtitle: context.l10n.autoRenewalSubtitle,
            value: autoRenewal,
            onChanged: onAutoRenewalChanged,
          ),
          _Divider(color: c.softBorder),
        ],
        _ActionRow(
          icon: LucideIcons.lockKeyhole,
          title: context.l10n.changePasswordTitle,
          subtitle: context.l10n.updateLoginPassword,
          onTap: onChangePassword,
        ),
        _Divider(color: c.softBorder),
        _ActionRow(
          icon: LucideIcons.logOut,
          title: context.l10n.logout,
          subtitle: context.l10n.logoutCurrentAccount,
          danger: true,
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: c.primary, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: danger ? c.danger : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
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

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final oldPassword = _oldCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (oldPassword.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      AppToast.show(
        context,
        context.l10n.passwordFieldsRequired,
        type: AppToastType.warning,
      );
      return;
    }
    if (newPassword != confirm) {
      AppToast.show(
        context,
        context.l10n.passwordsMismatch,
        type: AppToastType.warning,
      );
      return;
    }
    if (newPassword.length < 8) {
      AppToast.show(
        context,
        context.l10n.passwordTooShort,
        type: AppToastType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).changePasswordApi(
        oldPassword: oldPassword,
        newPassword: newPassword,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(
        context,
        context.l10n.passwordChanged,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: context.l10n.changePasswordTitle,
      children: [
        AppTextField(
          controller: _oldCtrl,
          label: context.l10n.currentPassword,
          hint: context.l10n.currentPasswordHint,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _newCtrl,
          label: context.l10n.newPassword,
          hint: context.l10n.newPasswordHint,
          obscureText: true,
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _confirmCtrl,
          label: context.l10n.confirmNewPassword,
          hint: context.l10n.confirmNewPasswordHint,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.lockKeyhole, size: 17),
            label: Text(
              _submitting ? context.l10n.updating : context.l10n.confirmChange,
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color);
  }
}

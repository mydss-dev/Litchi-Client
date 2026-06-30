import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../config/app_config.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/services/brand_asset_cache.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';

/// Account / Profile — a single responsive page.
///
/// Two-layout merge. Wide keeps the desktop account view (info card, shortcut
/// grid, login records — loaded via `_load` on first dependency change). Compact
/// keeps the mobile profile view (pull-to-refresh, profile header, menu section,
/// settings/password/logout bottom sheets). There are no field, method, or
/// sub-widget name collisions between the two, so this is a straight union: the
/// desktop state (`_load`/`_copy` + login data) and the mobile state (`_updating`
/// + sheet handlers) coexist untouched. Split on window width.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Wide-branch state (login info loaded on demand).
  bool _loading = true;
  String? _error;
  RemoteUser? _user;
  bool _initialized = false;

  // Compact-branch state.
  bool _updating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // The compact page renders AppController's already-loaded account
      // snapshot. The desktop-only detail request used to rebuild the compact
      // avatar after every navigation, producing a visible flash.
      if (!context.isCompact) _load();
    }
  }

  Future<void> _load() async {
    final ctrl = AppScope.of(context);
    final cached = ctrl.accountDetails;
    setState(() {
      _user = cached;
      _loading = cached == null;
      _error = null;
    });
    if (cached != null) return;
    try {
      final api = ctrl.api;
      final user = await api.getUserInfo();
      if (!mounted) return;
      ctrl.cacheAccountDetails(user);
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(
      context,
      context.l10n.itemCopied(label),
      type: AppToastType.success,
    );
  }

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
    return context.isCompact ? _buildCompact(context) : _buildWide(context);
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    final ctrl = AppScope.of(context);
    final visibleUser = ctrl.accountDetails ?? _user;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: PageHeader(
                  title: context.l10n.myAccount,
                  subtitle: context.l10n.myAccountSubtitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visibleUser != null)
            _AccountContent(
              user: visibleUser,
              onCopy: _copy,
              onNavigate: ctrl.goToPage,
            )
          else if (_loading)
            const PageLoadingCard()
          else if (_error != null)
            PageErrorCard(message: _error!, onRetry: _load),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    const summaryType = 'traffic';

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

// ── Wide-layout widgets (original desktop AccountPage, verbatim) ──────────

class _AccountContent extends StatelessWidget {
  const _AccountContent({
    required this.user,
    required this.onCopy,
    required this.onNavigate,
  });

  final RemoteUser user;
  final void Function(String text, String label) onCopy;
  final ValueChanged<AppPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final fallbackLetter = user.email.isNotEmpty
        ? user.email[0].toUpperCase()
        : 'L';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Avatar(fallbackLetter: fallbackLetter, size: 64),
          ),
        ),
        _AccountInfoCard(user: user, onCopy: onCopy),
        const SizedBox(height: 14),
        _AccountShortcutGrid(onNavigate: onNavigate),
      ],
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.user, required this.onCopy});

  final RemoteUser user;
  final void Function(String, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (statusLabel, statusColor) = switch (user.subscribeStatus) {
      1 => (context.l10n.expiredStatus, c.danger),
      2 => (context.l10n.suspendedStatus, c.warning),
      _ => (context.l10n.normalStatus, c.success),
    };

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.user, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n.accountInformation,
                style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: context.l10n.email,
            value: user.email,
            trailing: _CopyButton(
              onTap: () => onCopy(user.email, context.l10n.email),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  context.l10n.accountStatus,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
              AppBadge(
                text: statusLabel,
                background: statusColor.withValues(alpha: 0.12),
                textColor: statusColor,
                fontSize: 11,
                height: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: context.l10n.expiryTime, value: user.expiryDisplay),
        ],
      ),
    );
  }
}

class _AccountShortcutGrid extends StatelessWidget {
  const _AccountShortcutGrid({required this.onNavigate});

  final ValueChanged<AppPage> onNavigate;

  List<_AccountShortcut> _items(BuildContext context) => [
    _AccountShortcut(
      page: AppPage.wallet,
      icon: LucideIcons.walletCards,
      title: context.l10n.myWallet,
      subtitle: context.l10n.balanceAndRecharge,
    ),
    _AccountShortcut(
      page: AppPage.orders,
      icon: LucideIcons.clipboardList,
      title: context.l10n.orders,
      subtitle: context.l10n.purchaseAndPayment,
    ),
    _AccountShortcut(
      page: AppPage.traffic,
      icon: LucideIcons.chartNoAxesColumnIncreasing,
      title: context.l10n.trafficStatistics,
      subtitle: context.l10n.usageRecords,
    ),
    _AccountShortcut(
      page: AppPage.tickets,
      icon: LucideIcons.messageSquare,
      title: context.l10n.ticketSupport,
      subtitle: context.l10n.contactAfterSales,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _items(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _AccountShortcutTile(
              item: item,
              onTap: () => onNavigate(item.page),
            );
          },
        );
      },
    );
  }
}

class _AccountShortcut {
  const _AccountShortcut({
    required this.page,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final AppPage page;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _AccountShortcutTile extends StatefulWidget {
  const _AccountShortcutTile({required this.item, required this.onTap});

  final _AccountShortcut item;
  final VoidCallback onTap;

  @override
  State<_AccountShortcutTile> createState() => _AccountShortcutTileState();
}

class _AccountShortcutTileState extends State<_AccountShortcutTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover ? c.primarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: _hover ? c.primary : c.softBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(widget.item.icon, size: 18, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: c.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(color: c.textPrimary),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(LucideIcons.copy, size: 13, color: c.iconDefault),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.fallbackLetter, required this.size});

  final String fallbackLetter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final file = BrandAssetCache.avatarFile;
    if (BrandAssetCache.avatarUrl.isNotEmpty && file != null) {
      return ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: Image.file(file, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );
    }

    return _letterAvatar(c);
  }

  Widget _letterAvatar(AppColors c) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppConfig.brandGradient,
      ),
      child: Text(
        fallbackLetter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: Colors.white,
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
    required this.onTap,
  });

  final double usedGb;
  final double totalGb;
  final double remainGb;
  final int? resetDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final progress = totalGb <= 0 ? 0.0 : (usedGb / totalGb).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(0);
    final reset = resetDay == null || resetDay == 0
        ? context.l10n.resetDayUnavailable
        : context.l10n.monthlyResetDay(resetDay!);

    return AppCard(
      onTap: onTap,
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
              Text(
                reset,
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
      onTap: () => ctrl.goToPage(AppPage.traffic),
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
    required this.onManage,
  });

  final String userName;
  final String plan;
  final String expiry;
  final String avatar;
  final bool hidePlan;
  final bool hideExpiry;
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
          GestureDetector(
            onTap: onManage,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: c.primary.withValues(alpha: 0.20)),
                boxShadow: AppShadows.soft(c),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    color: c.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.manage,
                    style: AppTextStyles.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

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

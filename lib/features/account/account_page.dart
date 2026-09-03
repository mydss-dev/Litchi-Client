import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/core_platform_support.dart';
import '../../app/nav_destinations.dart';
import '../../config/app_config.dart';
import '../../config/panel_backend.dart';
import '../orders/orders_page.dart';
import '../shop/order_confirm_dialog.dart';
import 'wallet_page.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/brand_asset_cache.dart';
import '../../shared/services/windows_shell.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/no_plan_card.dart';

Future<void> showAccountChangePasswordModal(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

Future<bool> showAccountLogoutConfirmation(BuildContext context) async {
  final confirmed = await showAppAdaptiveModal<bool>(
    context: context,
    builder: (_) => const _LogoutSheet(),
  );
  return confirmed == true;
}

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

  void _showGiftCardModal() {
    final ctrl = AppScope.of(context);
    unawaited(
      showAppAdaptiveModal<void>(
        context: context,
        builder: (_) => _GiftCardRedeemModal(ctrl: ctrl),
      ),
    );
  }

  void _showTelegramModal() {
    final ctrl = AppScope.of(context);
    unawaited(
      showAppAdaptiveModal<void>(
        context: context,
        builder: (_) => _TelegramBindingModal(ctrl: ctrl),
      ),
    );
  }

  void _showChangePasswordSheet() {
    unawaited(showAccountChangePasswordModal(context));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAccountLogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    await AppScope.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    if (CorePlatformSupport.isDesktop) return _buildDesktop(context);
    return _buildCompact(context);
  }

  Widget _buildDesktop(BuildContext context) {
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final canRenew = isPageEnabled(AppPage.shop) && ctrl.hasPlan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileHeader(
          userName: user.name,
          plan: user.plan,
          expiry: user.expiry,
          avatar: user.avatarLetter,
          hidePlan: false,
          hideExpiry: false,
          onRenew: canRenew ? _renewCurrentPlan : null,
        ),
        const SizedBox(height: 14),
        if (!ctrl.hasPlan) ...[
          NoPlanCard(
            onPurchase: isPageEnabled(AppPage.shop)
                ? () => ctrl.goToPage(AppPage.shop)
                : null,
          ),
          const SizedBox(height: 14),
        ],
        _DesktopFundsAccount(
          ctrl: ctrl,
          onRecharge: () => unawaited(showWalletRechargeModal(context)),
          onTransfer: () => unawaited(showWalletTransferModal(context)),
          onWithdraw: () => unawaited(showWalletWithdrawModal(context)),
        ),
        const SizedBox(height: 16),
        _DesktopAccountServices(
          showXiaoServices: AppConfig.panelType == PanelType.xiaoV2board,
          telegramBound: ctrl.accountDetails?.telegramId != null,
          onOrders: () => unawaited(showOrdersModal(context)),
          onGiftCard: _showGiftCardModal,
          onTelegram: _showTelegramModal,
        ),
        const SizedBox(height: 16),
        _DesktopAccountSettings(
          hasPlan: ctrl.hasPlan,
          remindExpire: user.remindExpire,
          remindTraffic: user.remindTraffic,
          autoRenewal: user.autoRenewal,
          onExpireChanged: (value) => _updateSettings(remindExpire: value),
          onTrafficChanged: (value) => _updateSettings(remindTraffic: value),
          onAutoRenewalChanged: (value) => _updateSettings(autoRenewal: value),
          onChangePassword: _showChangePasswordSheet,
          onLogout: _confirmLogout,
        ),
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

Future<bool> _openExternalHttps(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    if (Platform.isWindows) return shellExecuteUrl(url);
    if (Platform.isMacOS) {
      return (await Process.run('open', [url])).exitCode == 0;
    }
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [url])).exitCode == 0;
    }
  } catch (_) {
    return false;
  }
  return false;
}

class _GiftCardRedeemModal extends StatefulWidget {
  const _GiftCardRedeemModal({required this.ctrl});

  final AppController ctrl;

  @override
  State<_GiftCardRedeemModal> createState() => _GiftCardRedeemModalState();
}

class _GiftCardRedeemModalState extends State<_GiftCardRedeemModal> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _submitting) {
      if (code.isEmpty) {
        setState(() => _error = context.l10n.giftCardEnterRequired);
      }
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ctrl.api.redeemGiftCard(code);
      await widget.ctrl.refreshData();
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.giftCardRedeemed,
        type: AppToastType.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.giftCardTitle,
      subtitle: context.l10n.giftCardModalSubtitle,
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            label: context.l10n.giftCardCode,
            hint: context.l10n.giftCardEnterHint,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: c.danger),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                _submitting
                    ? context.l10n.giftCardRedeeming
                    : context.l10n.giftCardRedeemNow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramBindingModal extends StatefulWidget {
  const _TelegramBindingModal({required this.ctrl});

  final AppController ctrl;

  @override
  State<_TelegramBindingModal> createState() => _TelegramBindingModalState();
}

class _TelegramBindingModalState extends State<_TelegramBindingModal> {
  String _botUsername = '';
  String? _error;
  bool _loading = true;
  bool _working = false;

  bool get _bound => widget.ctrl.accountDetails?.telegramId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBot());
  }

  Future<void> _loadBot() async {
    try {
      final username = await widget.ctrl.api.getTelegramBotUsername();
      if (!mounted) return;
      setState(() {
        _botUsername = username;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _copyBindCommand() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final subscribeUrl = await widget.ctrl.api.getSubscribeUrl();
      await Clipboard.setData(ClipboardData(text: '/bind $subscribeUrl'));
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.telegramBindingCommandCopied,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openTelegram() async {
    if (_botUsername.isEmpty) return;
    final opened = await _openExternalHttps('https://t.me/$_botUsername');
    if (!mounted || opened) return;
    setState(() {
      _error = context.l10n.telegramOpenFailed(_botUsername);
    });
  }

  Future<void> _refreshStatus() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.ctrl.refreshData();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _unbind() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.ctrl.api.unbindTelegram();
      await widget.ctrl.refreshData();
      if (!mounted) return;
      setState(() {});
      AppToast.show(
        context,
        context.l10n.telegramUnbound,
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = _bound
        ? context.l10n.telegramConnected
        : context.l10n.telegramNotConnected;
    return AppAdaptiveModal(
      title: 'Telegram',
      subtitle: context.l10n.telegramNotificationsSubtitle,
      maxWidth: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                _SmallIcon(icon: LucideIcons.send, color: c.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? context.l10n.telegramLoadingBot
                            : _botUsername.isEmpty
                            ? 'Telegram Bot'
                            : '@$_botUsername',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status,
                        style: AppTextStyles.caption.copyWith(
                          color: _bound ? c.success : c.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: c.danger),
            ),
          ],
          const SizedBox(height: 16),
          if (_bound)
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _working ? null : _unbind,
                child: Text(context.l10n.telegramUnbind),
              ),
            )
          else ...[
            Text(
              context.l10n.telegramBindingInstructions,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _working || _loading ? null : _copyBindCommand,
                      child: Text(context.l10n.telegramCopyCommand),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _loading || _botUsername.isEmpty
                          ? null
                          : _openTelegram,
                      child: Text(context.l10n.telegramOpen),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _working ? null : _refreshStatus,
              child: Text(context.l10n.telegramRefreshBindingStatus),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Desktop account widgets ──────────────────────────────────────────────

class _DesktopFundsAccount extends StatelessWidget {
  const _DesktopFundsAccount({
    required this.ctrl,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final AppController ctrl;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final balance = ctrl.user.balance / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopFundsLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(14),
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DesktopFundValue(
                      icon: LucideIcons.wallet,
                      label: context.l10n.accountBalance,
                      value:
                          '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
                    ),
                  ),
                  Container(width: 1, height: 44, color: c.softBorder),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DesktopFundValue(
                      icon: LucideIcons.badgeDollarSign,
                      label: context.l10n.withdrawableCommission,
                      value:
                          '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Divider(color: c.softBorder),
              const SizedBox(height: 10),
              _DesktopMoneyActions(
                onRecharge: onRecharge,
                onTransfer: onTransfer,
                onWithdraw: onWithdraw,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopFundValue extends StatelessWidget {
  const _DesktopFundValue({
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
    return Row(
      children: [
        _SmallIcon(icon: icon, color: c.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopMoneyActions extends StatelessWidget {
  const _DesktopMoneyActions({
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DesktopMoneyAction(
            label: context.l10n.rechargeBalance,
            onTap: onRecharge,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DesktopMoneyAction(
            label: context.l10n.transferCommission,
            onTap: onTransfer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DesktopMoneyAction(
            label: context.l10n.requestWithdrawal,
            onTap: onWithdraw,
          ),
        ),
      ],
    );
  }
}

class _DesktopMoneyAction extends StatelessWidget {
  const _DesktopMoneyAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.16)),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAccountServices extends StatelessWidget {
  const _DesktopAccountServices({
    required this.showXiaoServices,
    required this.telegramBound,
    required this.onOrders,
    required this.onGiftCard,
    required this.onTelegram,
  });

  final bool showXiaoServices;
  final bool telegramBound;
  final VoidCallback onOrders;
  final VoidCallback onGiftCard;
  final VoidCallback onTelegram;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final showOrders = isPageEnabled(AppPage.orders);
    if (!showOrders && !showXiaoServices) return const SizedBox.shrink();

    final rows = <Widget>[];
    void addRow(Widget row) {
      if (rows.isNotEmpty) rows.add(_Divider(color: c.softBorder));
      rows.add(row);
    }

    if (showOrders) {
      addRow(
        _ActionRow(
          icon: LucideIcons.clipboardList,
          title: desktopPageLabel(context, AppPage.orders),
          subtitle: context.l10n.ordersSubtitle,
          onTap: onOrders,
        ),
      );
    }
    if (showXiaoServices) {
      addRow(
        _ActionRow(
          icon: LucideIcons.ticketCheck,
          title: context.l10n.giftCardTitle,
          subtitle: context.l10n.giftCardServiceSubtitle,
          onTap: onGiftCard,
        ),
      );
      addRow(
        _ActionRow(
          icon: LucideIcons.send,
          title: 'Telegram',
          subtitle: telegramBound
              ? context.l10n.telegramServiceConnected
              : context.l10n.telegramServiceNotConnected,
          onTap: onTelegram,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopAccountServicesLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadow: AppCardShadow.soft,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _DesktopAccountSettings extends StatelessWidget {
  const _DesktopAccountSettings({
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
        Text(
          _desktopAccountSettingsLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadow: AppCardShadow.soft,
          child: Column(
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
          ),
        ),
      ],
    );
  }
}

String _desktopFundsLabel(BuildContext context) => context.l10n.accountAssets;

String _desktopAccountServicesLabel(BuildContext context) =>
    context.l10n.accountServices;

String _desktopAccountSettingsLabel(BuildContext context) =>
    context.l10n.accountManagement;

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
    this.onManage,
  });

  final String userName;
  final String plan;
  final String expiry;
  final String avatar;
  final bool hidePlan;
  final bool hideExpiry;
  final VoidCallback? onRenew;
  final VoidCallback? onManage;

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
          if (onRenew != null || onManage != null) ...[
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
                  if (onManage != null) const SizedBox(width: 6),
                ],
                if (onManage != null)
                  _ProfileActionButton(
                    icon: LucideIcons.slidersHorizontal,
                    label: context.l10n.manage,
                    onTap: onManage!,
                  ),
              ],
            ),
          ],
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

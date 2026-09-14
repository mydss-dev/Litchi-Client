import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../config/app_config.dart';
import '../../config/panel_backend.dart';
import '../../l10n/l10n.dart';
import '../../shared/layout/app_platform.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_spacing.dart';
import '../../shared/widgets/app_toast.dart';
import '../shop/order_confirm_dialog.dart';
import 'account_page.dart'
    show showAccountChangePasswordModal, showAccountLogoutConfirmation;
import 'wallet_page.dart';
import 'widgets/greenfield_account_modals.dart';
import 'widgets/greenfield_account_surface.dart';

class GreenfieldAccountPage extends StatefulWidget {
  const GreenfieldAccountPage({super.key});

  @override
  State<GreenfieldAccountPage> createState() => _GreenfieldAccountPageState();
}

class _GreenfieldAccountPageState extends State<GreenfieldAccountPage> {
  bool _updatingSettings = false;

  Future<void> _refresh() async {
    final controller = AppScope.of(context);
    await controller.refreshData();
    if (!mounted || controller.dataLoadError != null) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  Future<void> _updateSettings({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updatingSettings) return;
    final controller = AppScope.of(context);
    _updatingSettings = true;
    final error = await controller.updateUserSettings(
      remindExpire: remindExpire ?? controller.user.remindExpire,
      remindTraffic: remindTraffic ?? controller.user.remindTraffic,
      autoRenewal: autoRenewal ?? controller.user.autoRenewal,
    );
    if (!mounted) return;
    _updatingSettings = false;
    AppToast.show(
      context,
      error ?? context.l10n.settingsUpdated,
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _planAction() async {
    final controller = AppScope.of(context);
    if (!controller.hasPlan) {
      controller.goToPage(AppPage.shop);
      return;
    }

    final currentPlanId = controller.currentPlanId;
    PlanModel? currentPlan;
    if (currentPlanId != null) {
      for (final plan in controller.plans) {
        if (int.tryParse(plan.id) == currentPlanId) {
          currentPlan = plan;
          break;
        }
      }
    }

    if (currentPlan == null) {
      controller.goToPage(AppPage.shop);
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
      api: controller.api,
      onPaid: controller.refreshData,
    );
  }

  void _openChild(AppController controller, AppPage page) {
    if (!isPageEnabled(page)) return;
    if (AppPlatform.usesTouch) {
      controller.goToProfileChildPage(page);
    } else {
      controller.goToPage(page);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showAccountLogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    await AppScope.of(context).logout();
  }

  Widget _surface(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.user;
    final hasPlan = controller.hasPlan;
    final showXiaoServices = AppConfig.panelType == PanelType.xiaoV2board;
    final planName = user.plan.trim().isEmpty
        ? context.l10n.currentPlan
        : user.plan.trim();
    final expiryLabel = hasPlan
        ? (user.expiry.trim().isEmpty ? context.l10n.permanent : user.expiry)
        : context.l10n.noPlanDescription;
    final balanceText =
        '${controller.currencySymbol}${(user.balance / 100).toStringAsFixed(2)}';
    final commissionText =
        '${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}';

    return GreenfieldAccountSurface(
      userName: user.name,
      avatarLetter: user.avatarLetter,
      hasPlan: hasPlan,
      planName: planName,
      expiryLabel: expiryLabel,
      balanceText: balanceText,
      commissionText: commissionText,
      showGiftCard: showXiaoServices,
      showTelegram: showXiaoServices,
      telegramBound: controller.accountDetails?.telegramId != null,
      remindExpire: user.remindExpire,
      remindTraffic: user.remindTraffic,
      autoRenewal: user.autoRenewal,
      onPlanAction: () => unawaited(_planAction()),
      onWallet: () => _openChild(controller, AppPage.wallet),
      onRecharge: () => unawaited(showWalletRechargeModal(context)),
      onTransfer: () => unawaited(showWalletTransferModal(context)),
      onWithdraw: () => unawaited(showWalletWithdrawModal(context)),
      onOrders: () => _openChild(controller, AppPage.orders),
      onTraffic: () => _openChild(controller, AppPage.traffic),
      onInvite: () => controller.goToPage(AppPage.invite),
      onGiftCard: () => unawaited(showGreenfieldGiftCardModal(context)),
      onTelegram: () => unawaited(showGreenfieldTelegramModal(context)),
      onExpireChanged: (value) =>
          unawaited(_updateSettings(remindExpire: value)),
      onTrafficChanged: (value) =>
          unawaited(_updateSettings(remindTraffic: value)),
      onAutoRenewalChanged: (value) =>
          unawaited(_updateSettings(autoRenewal: value)),
      onChangePassword: () =>
          unawaited(showAccountChangePasswordModal(context)),
      onLogout: () => unawaited(_logout()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = _surface(context);
    if (!AppPlatform.usesTouch) return surface;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          surface,
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import '../shop/payment_dialog.dart';
import 'widgets/greenfield_wallet_modals.dart';
import 'widgets/greenfield_wallet_surface.dart';

class GreenfieldWalletPage extends StatefulWidget {
  const GreenfieldWalletPage({super.key});

  @override
  State<GreenfieldWalletPage> createState() => _GreenfieldWalletPageState();
}

class _GreenfieldWalletPageState extends State<GreenfieldWalletPage> {
  static const _presets = [10, 30, 50, 100, 200, 500, 1000, 2000];

  final _amountController = TextEditingController(text: '100');
  int _selectedPreset = 100;
  bool _submitting = false;
  bool _refreshing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final controller = AppScope.of(context);
    await controller.refreshData();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (controller.dataLoadError == null) {
      AppToast.show(
        context,
        context.l10n.refreshed,
        type: AppToastType.success,
      );
    }
  }

  Future<void> _submitRecharge() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      AppToast.show(
        context,
        context.l10n.invalidRechargeAmount,
        type: AppToastType.warning,
      );
      return;
    }
    if (_submitting) return;

    final controller = AppScope.of(context);
    setState(() => _submitting = true);
    try {
      final tradeNo = await controller.api.submitRechargeOrder(
        (amount * 100).round(),
      );
      if (!mounted) return;
      await showOrderPaymentDialog(
        context: context,
        tradeNo: tradeNo,
        finalPrice: amount,
        api: controller.api,
        currencySymbol: controller.currencySymbol,
      );
      if (mounted) await controller.refreshData();
    } catch (error) {
      if (mounted) {
        AppToast.show(
          context,
          error.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final balance = controller.user.balance / 100;
    final commission = controller.withdrawable;
    final total = balance + commission;
    final symbol = controller.currencySymbol;
    final minimumWithdrawalText = controller.minWithdrawAmount > 0
        ? '$symbol${controller.minWithdrawAmount.toStringAsFixed(2)}'
        : '';

    final surface = GreenfieldWalletSurface(
      totalText: '$symbol${total.toStringAsFixed(2)}',
      balanceText: '$symbol${balance.toStringAsFixed(2)}',
      commissionText: '$symbol${commission.toStringAsFixed(2)}',
      currencySymbol: symbol,
      presets: _presets,
      selectedPreset: _selectedPreset,
      amountController: _amountController,
      submitting: _submitting,
      withdrawEnabled: controller.withdrawEnabled,
      minimumWithdrawalText: minimumWithdrawalText,
      withdrawMethods: controller.withdrawMethods,
      onPresetSelected: (amount) {
        setState(() => _selectedPreset = amount);
        _amountController.text = amount.toString();
      },
      onOpenRecharge: () => showGreenfieldWalletRechargeModal(context),
      onSubmitRecharge: _submitRecharge,
      onTransfer: () => showGreenfieldWalletTransferModal(context),
      onWithdraw: () => showGreenfieldWalletWithdrawModal(context),
    );

    return ResponsivePageScaffold(
      title: context.l10n.myWallet,
      subtitle: context.l10n.myWalletSubtitle,
      compactTitle: context.l10n.wallet,
      compactSubtitle: context.l10n.walletSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.wallet),
      onRefresh: _refresh,
      onBack: () => controller.goToPage(AppPage.account),
      children: [surface],
    );
  }
}

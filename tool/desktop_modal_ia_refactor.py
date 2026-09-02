from pathlib import Path
import re


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    if old not in text:
        raise SystemExit(f"anchor not found in {path}: {old[:100]!r}")
    write(path, text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    text = read(path)
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f"regex replacement count={count} in {path}: {pattern[:100]!r}")
    write(path, text)


# ── Shared adaptive modal: desktop widths are explicit per task ──────────────
app_bottom_sheet = "lib/shared/widgets/app_bottom_sheet.dart"
replace_once(
    app_bottom_sheet,
    """    this.showHandle = true,\n    this.maxHeightFactor = 0.9,\n  });\n\n  final String title;\n  final String? subtitle;\n  final List<Widget> children;\n  final bool showHandle;\n  final double maxHeightFactor;\n""",
    """    this.showHandle = true,\n    this.maxHeightFactor = 0.9,\n    this.maxWidth = 560,\n  });\n\n  final String title;\n  final String? subtitle;\n  final List<Widget> children;\n  final bool showHandle;\n  final double maxHeightFactor;\n  final double maxWidth;\n""",
)
replace_once(app_bottom_sheet, "            maxWidth: 560,", "            maxWidth: maxWidth,")

app_modal = "lib/shared/widgets/app_modal.dart"
replace_once(
    app_modal,
    """    this.subtitle,\n    this.maxHeightFactor = 0.9,\n  });\n\n  final String title;\n  final String? subtitle;\n  final Widget child;\n  final double maxHeightFactor;\n""",
    """    this.subtitle,\n    this.maxHeightFactor = 0.9,\n    this.maxWidth = 560,\n  });\n\n  final String title;\n  final String? subtitle;\n  final Widget child;\n  final double maxHeightFactor;\n  final double maxWidth;\n""",
)
replace_once(
    app_modal,
    """      subtitle: subtitle,\n      maxHeightFactor: maxHeightFactor,\n      children: [child],\n""",
    """      subtitle: subtitle,\n      maxHeightFactor: maxHeightFactor,\n      maxWidth: maxWidth,\n      children: [child],\n""",
)

# ── Desktop navigation: Support is a first-class customer-service page ───────
nav = "lib/app/nav_destinations.dart"
replace_once(
    nav,
    """  DesktopNavDestination(page: AppPage.invite, icon: LucideIcons.gift),\n  DesktopNavDestination(page: AppPage.settings, icon: LucideIcons.settings),\n];\n\n/// Low-frequency account services shown once inside Account Overview.\nconst List<DesktopNavDestination> desktopAccountDestinations = [\n  DesktopNavDestination(page: AppPage.wallet, icon: LucideIcons.wallet),\n  DesktopNavDestination(page: AppPage.orders, icon: LucideIcons.clipboardList),\n  DesktopNavDestination(page: AppPage.tickets, icon: LucideIcons.messageSquare),\n];\n""",
    """  DesktopNavDestination(page: AppPage.invite, icon: LucideIcons.gift),\n  DesktopNavDestination(page: AppPage.tickets, icon: LucideIcons.messageSquare),\n  DesktopNavDestination(page: AppPage.settings, icon: LucideIcons.settings),\n];\n\n/// Account-associated routes remain available for compact navigation and deep\n/// links, but desktop account actions surface them without extra page hops.\nconst List<DesktopNavDestination> desktopAccountDestinations = [\n  DesktopNavDestination(page: AppPage.wallet, icon: LucideIcons.wallet),\n  DesktopNavDestination(page: AppPage.orders, icon: LucideIcons.clipboardList),\n];\n""",
)

# ── Wallet: expose focused modal actions while keeping the compact page ──────
wallet = "lib/features/account/wallet_page.dart"
replace_once(
    wallet,
    """/// Wallet — the mobile wallet page.\n""",
    """Future<void> showWalletRechargeModal(BuildContext context) {\n  return showAppAdaptiveModal<void>(\n    context: context,\n    builder: (_) => const _RechargeModal(),\n  );\n}\n\nFuture<void> showWalletTransferModal(BuildContext context) async {\n  final ctrl = AppScope.of(context);\n  if (ctrl.withdrawable <= 0) {\n    AppToast.show(\n      context,\n      context.l10n.noTransferableCommission,\n      type: AppToastType.warning,\n    );\n    return;\n  }\n  await showAppAdaptiveModal<void>(\n    context: context,\n    builder: (_) => _TransferModal(\n      maxAmount: ctrl.withdrawable,\n      currencySymbol: ctrl.currencySymbol,\n    ),\n  );\n  if (context.mounted) await ctrl.refreshData();\n}\n\nFuture<void> showWalletWithdrawModal(BuildContext context) async {\n  final ctrl = AppScope.of(context);\n  if (!ctrl.withdrawEnabled) {\n    AppToast.show(\n      context,\n      context.l10n.withdrawalUnavailable,\n      type: AppToastType.warning,\n    );\n    return;\n  }\n  if (ctrl.withdrawable <= 0) {\n    AppToast.show(\n      context,\n      context.l10n.noWithdrawableCommission,\n      type: AppToastType.warning,\n    );\n    return;\n  }\n  if (ctrl.withdrawMethods.isEmpty) {\n    AppToast.show(\n      context,\n      context.l10n.noWithdrawalMethods,\n      type: AppToastType.warning,\n    );\n    return;\n  }\n  await showAppAdaptiveModal<void>(\n    context: context,\n    builder: (_) => _WithdrawModal(\n      maxAmount: ctrl.withdrawable,\n      minAmount: ctrl.minWithdrawAmount,\n      methods: ctrl.withdrawMethods,\n      currencySymbol: ctrl.currencySymbol,\n    ),\n  );\n  if (context.mounted) await ctrl.refreshData();\n}\n\n/// Wallet — the mobile wallet page.\n""",
)
regex_once(
    wallet,
    r"  Future<void> _transferCommission\(\) async \{.*?\n  \}\n\n  Future<void> _withdrawCommission\(\) async \{.*?\n  \}\n",
    """  Future<void> _transferCommission() => showWalletTransferModal(context);\n\n  Future<void> _withdrawCommission() => showWalletWithdrawModal(context);\n""",
)
replace_once(
    wallet,
    """// ── Wallet hero card ──────────────────────────────────────────────────────────\n""",
    """// ── Focused recharge modal ───────────────────────────────────────────────────\n\nclass _RechargeModal extends StatefulWidget {\n  const _RechargeModal();\n\n  @override\n  State<_RechargeModal> createState() => _RechargeModalState();\n}\n\nclass _RechargeModalState extends State<_RechargeModal> {\n  static const _presets = [10, 30, 50, 100, 200, 500, 1000, 2000];\n\n  final _amountCtrl = TextEditingController(text: '100');\n  int _selectedPreset = 100;\n  bool _submitting = false;\n\n  @override\n  void dispose() {\n    _amountCtrl.dispose();\n    super.dispose();\n  }\n\n  Future<void> _submit() async {\n    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;\n    if (amount <= 0) {\n      AppToast.show(\n        context,\n        context.l10n.invalidRechargeAmount,\n        type: AppToastType.warning,\n      );\n      return;\n    }\n    if (_submitting) return;\n\n    final ctrl = AppScope.of(context);\n    final dialogContext = Navigator.of(context, rootNavigator: true).context;\n    setState(() => _submitting = true);\n    try {\n      final tradeNo = await ctrl.api.submitRechargeOrder(\n        (amount * 100).round(),\n      );\n      if (!mounted) return;\n      Navigator.of(context).pop();\n      await showOrderPaymentDialog(\n        context: dialogContext,\n        tradeNo: tradeNo,\n        finalPrice: amount,\n        api: ctrl.api,\n        currencySymbol: ctrl.currencySymbol,\n      );\n      await ctrl.refreshData();\n    } catch (e) {\n      if (dialogContext.mounted) {\n        AppToast.show(\n          dialogContext,\n          e.toString().replaceFirst('ApiException: ', ''),\n          type: AppToastType.error,\n        );\n      }\n    } finally {\n      if (mounted) setState(() => _submitting = false);\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final ctrl = AppScope.of(context);\n    return AppAdaptiveModal(\n      title: context.l10n.rechargeBalance,\n      subtitle: context.l10n.rechargeBalanceNotice,\n      child: Column(\n        mainAxisSize: MainAxisSize.min,\n        crossAxisAlignment: CrossAxisAlignment.stretch,\n        children: [\n          LayoutBuilder(\n            builder: (context, constraints) {\n              final columns = constraints.maxWidth >= 460 ? 4 : 2;\n              const gap = 10.0;\n              final width =\n                  (constraints.maxWidth - gap * (columns - 1)) / columns;\n              return Wrap(\n                spacing: gap,\n                runSpacing: gap,\n                children: [\n                  for (final value in _presets)\n                    _PresetChip(\n                      label: '${ctrl.currencySymbol}$value',\n                      selected: value == _selectedPreset,\n                      width: width,\n                      onTap: () {\n                        setState(() => _selectedPreset = value);\n                        _amountCtrl.text = value.toString();\n                      },\n                    ),\n                ],\n              );\n            },\n          ),\n          const SizedBox(height: 16),\n          _RechargeAmountRow(\n            controller: _amountCtrl,\n            currencySymbol: ctrl.currencySymbol,\n            submitting: _submitting,\n            onSubmit: _submit,\n          ),\n        ],\n      ),\n    );\n  }\n}\n\n// ── Wallet hero card ──────────────────────────────────────────────────────────\n""",
)

# ── Orders: desktop opens the existing order experience as a modal ──────────
orders = "lib/features/orders/orders_page.dart"
replace_once(
    orders,
    """class OrdersPage extends StatefulWidget {\n  const OrdersPage({super.key});\n\n  @override\n  State<OrdersPage> createState() => _OrdersPageState();\n}\n""",
    """Future<void> showOrdersModal(BuildContext context) {\n  return showAppAdaptiveModal<void>(\n    context: context,\n    builder: (_) => const OrdersPage(modal: true),\n  );\n}\n\nclass OrdersPage extends StatefulWidget {\n  const OrdersPage({super.key, this.modal = false});\n\n  final bool modal;\n\n  @override\n  State<OrdersPage> createState() => _OrdersPageState();\n}\n""",
)
replace_once(
    orders,
    """  @override\n  Widget build(BuildContext context) {\n    return ResponsivePageScaffold(\n""",
    """  @override\n  Widget build(BuildContext context) {\n    if (widget.modal) {\n      return AppAdaptiveModal(\n        title: context.l10n.orders,\n        subtitle: context.l10n.orderHistorySubtitle,\n        maxWidth: 760,\n        maxHeightFactor: 0.86,\n        child: Column(\n          mainAxisSize: MainAxisSize.min,\n          crossAxisAlignment: CrossAxisAlignment.stretch,\n          children: _bodyChildren(context),\n        ),\n      );\n    }\n    return ResponsivePageScaffold(\n""",
)

# ── Account: balance owns money actions; order history is a modal ────────────
account = "lib/features/account/account_page.dart"
replace_once(
    account,
    """import '../../shared/widgets/app_bottom_sheet.dart';\nimport '../../shared/widgets/app_card.dart';\n""",
    """import '../../shared/widgets/app_bottom_sheet.dart';\nimport '../../shared/widgets/app_card.dart';\nimport '../../shared/widgets/app_modal.dart';\n""",
)
replace_once(
    account,
    """import '../shop/order_confirm_dialog.dart';\n""",
    """import '../orders/orders_page.dart';\nimport '../shop/order_confirm_dialog.dart';\nimport 'wallet_page.dart';\n""",
)
replace_once(
    account,
    """  return showAppBottomSheet<void>(\n    context: context,\n    builder: (_) => const _ChangePasswordSheet(),\n  );\n""",
    """  return showAppAdaptiveModal<void>(\n    context: context,\n    builder: (_) => const _ChangePasswordSheet(),\n  );\n""",
)
replace_once(
    account,
    """  final confirmed = await showAppBottomSheet<bool>(\n    context: context,\n    builder: (_) => const _LogoutSheet(),\n  );\n""",
    """  final confirmed = await showAppAdaptiveModal<bool>(\n    context: context,\n    builder: (_) => const _LogoutSheet(),\n  );\n""",
)
replace_once(
    account,
    """        if (!ctrl.hasPlan)\n          NoPlanCard(\n            onPurchase: isPageEnabled(AppPage.shop)\n                ? () => ctrl.goToPage(AppPage.shop)\n                : null,\n          )\n        else\n          _DesktopAccountMetrics(ctrl: ctrl),\n        const SizedBox(height: 16),\n        _DesktopAccountServices(ctrl: ctrl),\n""",
    """        if (!ctrl.hasPlan) ...[\n          NoPlanCard(\n            onPurchase: isPageEnabled(AppPage.shop)\n                ? () => ctrl.goToPage(AppPage.shop)\n                : null,\n          ),\n          const SizedBox(height: 14),\n        ],\n        _DesktopAccountMetrics(\n          ctrl: ctrl,\n          onRecharge: () => unawaited(showWalletRechargeModal(context)),\n          onTransfer: () => unawaited(showWalletTransferModal(context)),\n          onWithdraw: () => unawaited(showWalletWithdrawModal(context)),\n        ),\n        const SizedBox(height: 16),\n        _DesktopAccountServices(\n          onOrders: () => unawaited(showOrdersModal(context)),\n        ),\n""",
)
regex_once(
    account,
    r"class _DesktopAccountMetrics extends StatelessWidget \{.*?\nclass _DesktopAccountServices extends StatelessWidget \{",
    r'''class _DesktopAccountMetrics extends StatelessWidget {
  const _DesktopAccountMetrics({
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
              child: _DesktopBalanceMetric(
                value: '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
                commission:
                    '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}',
                onRecharge: onRecharge,
                onTransfer: onTransfer,
                onWithdraw: onWithdraw,
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
      height: 116,
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
                  maxLines: 2,
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

class _DesktopBalanceMetric extends StatelessWidget {
  const _DesktopBalanceMetric({
    required this.value,
    required this.commission,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final String value;
  final String commission;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      height: 116,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      shadow: AppCardShadow.soft,
      child: Column(
        children: [
          Row(
            children: [
              _SmallIcon(icon: LucideIcons.wallet, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.accountBalance,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          value,
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: c.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${context.l10n.withdrawableCommission} $commission',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                              fontSize: 10,
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
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _DesktopMoneyAction(
                  label: context.l10n.rechargeBalance,
                  onTap: onRecharge,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DesktopMoneyAction(
                  label: context.l10n.transferShort,
                  onTap: onTransfer,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _DesktopMoneyAction(
                  label: context.l10n.withdrawShort,
                  onTap: onWithdraw,
                ),
              ),
            ],
          ),
        ],
      ),
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
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.16)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(
              color: c.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAccountServices extends StatelessWidget {''',
)
regex_once(
    account,
    r"class _DesktopAccountServices extends StatelessWidget \{.*?\nclass _DesktopAccountSettings extends StatelessWidget \{",
    r'''class _DesktopAccountServices extends StatelessWidget {
  const _DesktopAccountServices({required this.onOrders});

  final VoidCallback onOrders;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!isPageEnabled(AppPage.orders)) return const SizedBox.shrink();

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
          child: _ActionRow(
            icon: LucideIcons.clipboardList,
            title: desktopPageLabel(context, AppPage.orders),
            subtitle: context.l10n.ordersSubtitle,
            onTap: onOrders,
          ),
        ),
      ],
    );
  }
}

class _DesktopAccountSettings extends StatelessWidget {''',
)
replace_once(
    account,
    """  if (locale.languageCode != 'zh') return 'Account services';\n""",
    """  if (locale.languageCode != 'zh') return 'Account history';\n""",
)
replace_once(
    account,
    """  return traditional ? '帳戶服務' : '账户服务';\n""",
    """  return traditional ? '帳戶記錄' : '账户记录';\n""",
)

# ── Node picker: desktop gets a real centered modal, compact keeps sheet ─────
node_picker = "lib/features/nodes/node_picker.dart"
replace_once(
    node_picker,
    """import '../../app/app_controller.dart';\n""",
    """import '../../app/app_controller.dart';\nimport '../../app/core_platform_support.dart';\n""",
)
replace_once(
    node_picker,
    """  @override\n  Widget build(BuildContext context) {\n    final bottom = MediaQuery.viewInsetsOf(context).bottom;\n""",
    """  @override\n  Widget build(BuildContext context) {\n    if (CorePlatformSupport.isDesktop) return _buildDesktopModal();\n    final bottom = MediaQuery.viewInsetsOf(context).bottom;\n""",
)
replace_once(
    node_picker,
    """  Widget _buildSurface([ScrollController? scrollController]) {\n""",
    """  Widget _buildDesktopModal() {\n    final ctrl = AppScope.of(context);\n    final c = AppColors.of(context);\n    final nodes = _filteredNodes(ctrl);\n    final testing = ctrl.nodes.any((node) => node.latency < 0);\n    final listHeight =\n        (MediaQuery.sizeOf(context).height * 0.58).clamp(360.0, 520.0).toDouble();\n\n    return AppAdaptiveModal(\n      title: context.l10n.chooseNode,\n      subtitle: ctrl.nodes.isNotEmpty\n          ? context.l10n.nodeCountSummary(ctrl.nodes.length)\n          : context.l10n.noNodesSubscription,\n      maxWidth: 720,\n      maxHeightFactor: 0.88,\n      child: SizedBox(\n        height: listHeight,\n        child: Column(\n          children: [\n            Row(\n              children: [\n                Expanded(\n                  child: SearchInput(\n                    hintText: context.l10n.searchNodes,\n                    onChanged: (value) => setState(() => _query = value),\n                  ),\n                ),\n                const SizedBox(width: 10),\n                IconButton(\n                  tooltip: context.l10n.latencyTest,\n                  onPressed: testing ? null : () => _testLatencies(ctrl),\n                  icon: testing\n                      ? SizedBox(\n                          width: 18,\n                          height: 18,\n                          child: CircularProgressIndicator(\n                            strokeWidth: 2,\n                            color: c.primary,\n                          ),\n                        )\n                      : Icon(LucideIcons.gauge, color: c.primary, size: 19),\n                ),\n              ],\n            ),\n            const SizedBox(height: 12),\n            FilterTabs(\n              tabs: _filterLabels(context),\n              selectedIndex: _filterIndex,\n              onSelected: (index) => setState(() => _filterIndex = index),\n            ),\n            const SizedBox(height: 12),\n            Expanded(\n              child: CustomScrollView(\n                slivers: [\n                  SliverToBoxAdapter(\n                    child: _AutoSelectTile(\n                      ctrl: ctrl,\n                      selected: ctrl.autoSelected,\n                      onTap: () => _selectAuto(ctrl),\n                    ),\n                  ),\n                  const SliverToBoxAdapter(child: SizedBox(height: 10)),\n                  if (nodes.isEmpty)\n                    SliverPadding(\n                      padding: const EdgeInsets.symmetric(vertical: 24),\n                      sliver: SliverToBoxAdapter(\n                        child: AppCard(\n                          color: c.surfaceMuted,\n                          shadow: AppCardShadow.none,\n                          child: AppEmptyState(\n                            icon: _query.trim().isNotEmpty || _filterIndex != 0\n                                ? LucideIcons.searchX\n                                : LucideIcons.globe2,\n                            title: _query.trim().isNotEmpty || _filterIndex != 0\n                                ? context.l10n.noMatchingNodes\n                                : context.l10n.noNodes,\n                            subtitle:\n                                _query.trim().isNotEmpty || _filterIndex != 0\n                                ? context.l10n.tryDifferentNodeFilter\n                                : context.l10n.waitForSubscription,\n                          ),\n                        ),\n                      ),\n                    )\n                  else\n                    _buildNodeSliver(ctrl, nodes, 0),\n                ],\n              ),\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n\n  Widget _buildSurface([ScrollController? scrollController]) {\n""",
)

print("desktop modal IA refactor staged successfully")

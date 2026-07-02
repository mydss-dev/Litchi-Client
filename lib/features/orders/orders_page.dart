import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/app_error_message_service.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import '../shop/payment_dialog.dart';

/// Order history — a single responsive page.
///
/// The order card and all its sub-widgets are shared. Only the surrounding
/// affordances adapt to width, keeping the better interaction on each form
/// factor: pull-to-refresh + a bottom-sheet cancel confirm on narrow screens,
/// a refresh button + a dialog cancel confirm (with hover cursors) on wide
/// screens.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<RemoteOrder> _orders = const [];
  String? _activeTradeNo;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await AppScope.of(context).api.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  Future<void> _handleRefresh() async {
    await _load();
    if (!mounted || _error != null) return;
    AppToast.show(context, context.l10n.refreshed, type: AppToastType.success);
  }

  Future<void> _payOrder(RemoteOrder order) async {
    if (_activeTradeNo != null) return;
    setState(() => _activeTradeNo = order.tradeNo);
    final ctrl = AppScope.of(context);
    final api = ctrl.api;
    try {
      await showOrderPaymentDialog(
        context: context,
        tradeNo: order.tradeNo,
        finalPrice: order.totalAmount / 100,
        api: api,
        onPaid: ctrl.refreshData,
      );
      if (mounted) unawaited(_load());
    } finally {
      if (mounted) setState(() => _activeTradeNo = null);
    }
  }

  Future<void> _cancelOrder(RemoteOrder order) async {
    if (_activeTradeNo != null) return;
    setState(() => _activeTradeNo = order.tradeNo);

    final confirmed = await showAppAdaptiveModal<bool>(
      context: context,
      builder: (_, compact) =>
          _CancelOrderModal(compact: compact, orderNo: order.tradeNo),
    );

    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _activeTradeNo = null);
      return;
    }

    try {
      await AppScope.of(context).api.cancelOrder(order.tradeNo);
      if (!mounted) return;
      AppToast.show(
        context,
        context.l10n.orderCancelled,
        type: AppToastType.info,
      );
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _activeTradeNo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: context.l10n.orders,
      subtitle: context.l10n.orderHistorySubtitle,
      compactTitle: context.l10n.order,
      compactSubtitle: context.l10n.ordersSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.orders),
      onRefresh: _handleRefresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      showWideRefresh: !_loading,
      children: _bodyChildren(context),
    );
  }

  // ── Shared body (loading / error / empty / list) ───────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    if (_loading) {
      return const [PageLoadingCard()];
    }
    if (_error != null) {
      return [
        PageStateCard(
          icon: LucideIcons.circleAlert,
          title: context.l10n.orderLoadFailed,
          subtitle: AppErrorMessageService.userFacing(_error!, context.l10n),
          onTap: _load,
        ),
      ];
    }
    if (_orders.isEmpty) {
      return [
        PageStateCard(
          icon: LucideIcons.receipt,
          title: context.l10n.noOrders,
          subtitle: context.l10n.ordersAppearAfterPurchase,
        ),
      ];
    }
    return [
      for (final order in _orders) ...[
        _OrderCard(
          order: order,
          busy: _activeTradeNo == order.tradeNo,
          onPay: order.status == 0 ? () => _payOrder(order) : null,
          onCancel: order.status == 0 ? () => _cancelOrder(order) : null,
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.busy,
    this.onPay,
    this.onCancel,
  });

  final RemoteOrder order;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currencySymbol = AppScope.of(context).currencySymbol;
    final statusColor = switch (order.status) {
      0 => c.warning,
      1 => c.primary,
      2 => c.textMuted,
      3 => c.success,
      4 => c.success,
      _ => c.textMuted,
    };
    final orderNo = order.tradeNo.isEmpty ? '--' : order.tradeNo;
    final isDeposit = order.period == 'deposit';
    final typeValue = isDeposit
        ? context.l10n.accountTopUp
        : _localizedPeriod(context, order.period, order.periodLabel);

    return AppCard(
      padding: const EdgeInsets.all(16),
      shadow: AppCardShadow.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(LucideIcons.receipt, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.orderNumber(orderNo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _OrderMeta(label: context.l10n.type, value: typeValue),
                ),
                Expanded(
                  child: _OrderMeta(
                    label: context.l10n.date,
                    value: order.dateDisplay,
                  ),
                ),
                Expanded(
                  child: _OrderMeta(
                    label: context.l10n.amount,
                    value: order.amountDisplay(currencySymbol),
                  ),
                ),
                Expanded(
                  child: _OrderMeta(
                    label: context.l10n.status,
                    value: _localizedOrderStatus(context, order.status),
                    valueColor: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (onPay != null || onCancel != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: _OrderActionButton(
                      label: context.l10n.cancelOrder,
                      icon: LucideIcons.x,
                      color: c.textMuted,
                      onTap: busy ? null : onCancel,
                    ),
                  ),
                if (onCancel != null && onPay != null)
                  const SizedBox(width: 10),
                if (onPay != null)
                  Expanded(
                    flex: 2,
                    child: _OrderActionButton(
                      label: context.l10n.continuePayment,
                      icon: LucideIcons.creditCard,
                      color: c.primary,
                      filled: true,
                      loading: busy,
                      onTap: busy ? null : onPay,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderMeta extends StatelessWidget {
  const _OrderMeta({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '--' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? c.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _OrderActionButton extends StatelessWidget {
  const _OrderActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: filled ? color : c.softBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : color,
                  ),
                )
              else
                Icon(icon, size: 16, color: filled ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                loading ? context.l10n.processing : label,
                style: AppTextStyles.button.copyWith(
                  color: filled ? Colors.white : color,
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

// ── Cancel confirmation: dialog (wide) and bottom sheet (compact) ────────────

class _CancelOrderBody extends StatelessWidget {
  const _CancelOrderBody({required this.submitting, required this.onConfirm});

  final bool submitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
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
                  context.l10n.cancelOrderConfirm,
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
                  child: Text(context.l10n.thinkAgain),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: submitting ? null : onConfirm,
                  style: FilledButton.styleFrom(backgroundColor: c.danger),
                  child: Text(
                    submitting
                        ? context.l10n.processing
                        : context.l10n.confirmCancel,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CancelOrderModal extends StatefulWidget {
  const _CancelOrderModal({required this.compact, required this.orderNo});

  final bool compact;
  final String orderNo;

  @override
  State<_CancelOrderModal> createState() => _CancelOrderModalState();
}

class _CancelOrderModalState extends State<_CancelOrderModal> {
  bool _submitting = false;

  void _confirm() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveModal(
      compact: widget.compact,
      title: context.l10n.cancelOrder,
      subtitle: widget.orderNo.isEmpty
          ? null
          : context.l10n.orderNumber(widget.orderNo),
      maxWidth: 420,
      showCloseButton: false,
      child: _CancelOrderBody(submitting: _submitting, onConfirm: _confirm),
    );
  }
}

String _localizedOrderStatus(BuildContext context, int status) =>
    switch (status) {
      0 => context.l10n.orderPending,
      1 => context.l10n.orderProcessing,
      2 => context.l10n.orderCancelledStatus,
      3 => context.l10n.orderCompleted,
      4 => context.l10n.orderDiscounted,
      _ => context.l10n.unknown,
    };

String _localizedPeriod(BuildContext context, String period, String fallback) =>
    switch (period) {
      'month_price' => context.l10n.monthly,
      'quarter_price' => context.l10n.quarterly,
      'half_year_price' => context.l10n.halfYear,
      'year_price' => context.l10n.yearly,
      'two_year_price' => context.l10n.twoYears,
      'three_year_price' => context.l10n.threeYears,
      'onetime_price' => context.l10n.buyout,
      _ => fallback,
    };

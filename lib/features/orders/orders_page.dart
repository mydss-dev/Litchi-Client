import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../config/mobile_layout.dart';
import '../../shared/models/api_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../mobile/mobile_back_button.dart';
import '../mobile/mobile_page_header.dart';
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
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  Future<void> _payOrder(RemoteOrder order) async {
    if (_activeTradeNo != null) return;
    setState(() => _activeTradeNo = order.tradeNo);
    final api = AppScope.of(context).api;
    try {
      await showOrderPaymentDialog(
        context: context,
        tradeNo: order.tradeNo,
        finalPrice: order.totalAmount / 100,
        api: api,
      );
      if (mounted) unawaited(_load());
    } finally {
      if (mounted) setState(() => _activeTradeNo = null);
    }
  }

  Future<void> _cancelOrder(RemoteOrder order) async {
    if (_activeTradeNo != null) return;
    setState(() => _activeTradeNo = order.tradeNo);

    // Adaptive confirm: bottom sheet on touch-sized layouts, dialog otherwise.
    final confirmed = context.isCompact
        ? await showAppBottomSheet<bool>(
            context: context,
            builder: (_) => _CancelOrderSheet(orderNo: order.tradeNo),
          )
        : await showDialog<bool>(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.42),
            builder: (_) => _CancelOrderDialog(orderNo: order.tradeNo),
          );

    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _activeTradeNo = null);
      return;
    }

    try {
      await AppScope.of(context).api.cancelOrder(order.tradeNo);
      if (!mounted) return;
      AppToast.show(context, '订单已取消', type: AppToastType.info);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Breakpoints.isCompactWidth(constraints.maxWidth)) {
          return _buildCompact(context);
        }
        return _buildWide(context);
      },
    );
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────────

  Widget _buildWide(BuildContext context) {
    final ctrl = AppScope.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PageBackButton(
                onTap: () => ctrl.goToPage(AppPage.account),
                tooltip: '返回我的',
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: PageHeader(title: '订单记录', subtitle: '查看购买与支付记录'),
              ),
              if (!_loading) ...[
                const SizedBox(width: 10),
                RefreshIconButton(onTap: _handleRefresh),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ..._bodyChildren(context),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final asPrimary = _isPrimaryMobileTab('orders');
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          if (asPrimary)
            const MobilePageHeader(
              title: '订单',
              subtitle: '查看购买记录与支付状态',
            )
          else
            Row(
              children: [
                MobileBackButton(
                  onTap: () => AppScope.of(context).goToPage(AppPage.account),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '订单记录',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 26),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          ..._bodyChildren(context),
        ],
      ),
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
          title: '订单加载失败',
          subtitle: _error!,
          onTap: _load,
        ),
      ];
    }
    if (_orders.isEmpty) {
      return const [
        PageStateCard(
          icon: LucideIcons.receipt,
          title: '暂无订单',
          subtitle: '购买套餐后会显示在这里',
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

bool _isPrimaryMobileTab(String type) {
  return MobileLayout.tabs.any((tab) => tab.type == type);
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
    final statusColor = switch (order.status) {
      0 => c.warning,
      1 => c.primary,
      2 => c.textMuted,
      3 => c.success,
      4 => c.danger,
      _ => c.textMuted,
    };
    final orderNo = order.tradeNo.isEmpty ? '--' : order.tradeNo;
    final isDeposit = order.period == 'deposit';
    final typeValue = isDeposit ? '账户充值' : order.periodLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
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
                  '订单号 $orderNo',
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
                Expanded(child: _OrderMeta(label: '类型', value: typeValue)),
                Expanded(
                  child: _OrderMeta(label: '日期', value: order.dateDisplay),
                ),
                Expanded(
                  child: _OrderMeta(label: '金额', value: order.amountDisplay),
                ),
                Expanded(
                  child: _OrderMeta(
                    label: '状态',
                    value: order.statusLabel,
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
                      label: '取消订单',
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
                      label: '继续支付',
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
                loading ? '处理中' : label,
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
                  '确认取消该待支付订单？取消后需要重新下单。',
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
                  child: const Text('再想想'),
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
                  child: Text(submitting ? '处理中' : '确认取消'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog({required this.orderNo});

  final String orderNo;

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  bool _submitting = false;

  void _confirm() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.card(c),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '取消订单',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                ),
              ),
              if (widget.orderNo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '订单号 ${widget.orderNo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
              const SizedBox(height: 16),
              _CancelOrderBody(submitting: _submitting, onConfirm: _confirm),
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet({required this.orderNo});

  final String orderNo;

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  bool _submitting = false;

  void _confirm() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '取消订单',
      subtitle: widget.orderNo.isEmpty ? null : '订单号 ${widget.orderNo}',
      children: [
        _CancelOrderBody(submitting: _submitting, onConfirm: _confirm),
      ],
    );
  }
}

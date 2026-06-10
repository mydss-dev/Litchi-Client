import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../shop/payment_dialog.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _loading = true;
  String? _error;
  List<RemoteOrder> _orders = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _payOrder(RemoteOrder order) async {
    final api = AppScope.of(context).api;
    await showOrderPaymentDialog(
      context: context,
      tradeNo: order.tradeNo,
      finalPrice: order.totalAmount / 100.0,
      api: api,
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _cancelOrder(RemoteOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _CancelConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppScope.of(context).api.cancelOrder(order.tradeNo);
      if (mounted) {
        AppToast.show(context, '订单已取消', type: AppToastType.info);
        unawaited(_load());
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await AppScope.of(context).api.fetchOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('ApiException: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: PageHeader(title: '我的订单', subtitle: '查看购买记录'),
              ),
              if (!_loading) RefreshIconButton(onTap: _load),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const PageLoadingCard()
          else if (_error != null)
            PageErrorCard(message: _error!, onRetry: _load)
          else if (_orders.isEmpty)
            AppCard(
              radius: AppRadius.card,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Column(
                children: [
                  Icon(LucideIcons.shoppingCart,
                      size: 36, color: c.iconMuted),
                  const SizedBox(height: 12),
                  Text('暂无订单记录',
                      style: AppTextStyles.body.copyWith(color: c.textMuted)),
                ],
              ),
            )
          else
            Column(
              children: [
                for (final order in _orders) ...[
                  _OrderCard(
                    order: order,
                    onPay: order.status == 0 ? () => _payOrder(order) : null,
                    onCancel: order.status == 0 ? () => _cancelOrder(order) : null,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.onTap, required this.color});
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelConfirmDialog extends StatelessWidget {
  const _CancelConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: [
              BoxShadow(
                  color: c.shadow, blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(LucideIcons.circleAlert, size: 24, color: c.danger),
              ),
              const SizedBox(height: 16),
              Text('取消订单',
                  style:
                      AppTextStyles.pageTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 8),
              Text('确认取消该待支付订单？',
                  style: AppTextStyles.body.copyWith(color: c.textMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: c.border),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text('再想想',
                            style: AppTextStyles.button
                                .copyWith(color: c.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.danger,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text('确认取消',
                            style: AppTextStyles.button
                                .copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onPay, this.onCancel});
  final RemoteOrder order;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final (statusColor) = switch (order.status) {
      0 => c.warning,
      1 => c.primary,
      2 => c.textMuted,
      3 => c.success,
      4 => c.danger,
      _ => c.textMuted,
    };

    final tradeNoShort = order.tradeNo.length > 16
        ? '${order.tradeNo.substring(0, 16)}…'
        : order.tradeNo;

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(LucideIcons.receipt, size: 16, color: c.iconDefault),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.planName ?? '套餐订单',
                            style: AppTextStyles.bodyStrong
                                .copyWith(color: c.textPrimary),
                          ),
                        ),
                        AppBadge(
                          text: order.statusLabel,
                          background: statusColor.withValues(alpha: 0.12),
                          textColor: statusColor,
                          fontSize: 11,
                          height: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          order.periodLabel,
                          style: AppTextStyles.caption
                              .copyWith(color: c.textMuted),
                        ),
                        const SizedBox(width: 8),
                        Text('·',
                            style: AppTextStyles.caption
                                .copyWith(color: c.textMuted)),
                        const SizedBox(width: 8),
                        Text(
                          tradeNoShort,
                          style: AppTextStyles.caption
                              .copyWith(color: c.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    order.amountDisplay,
                    style:
                        AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.dateDisplay,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ],
          ),
          if (order.status == 0) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: c.softBorder),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCancel != null)
                  _ActionBtn(
                    label: '取消订单',
                    onTap: onCancel!,
                    color: c.danger,
                  ),
                if (onPay != null) ...[
                  const SizedBox(width: 8),
                  _ActionBtn(
                    label: '去支付',
                    onTap: onPay!,
                    color: c.primary,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

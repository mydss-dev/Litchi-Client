import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../app/nav_destinations.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/app_error_message_service.dart';
import '../../shared/widgets/app_modal.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';
import '../shop/payment_dialog.dart';
import 'widgets/greenfield_cancel_order_modal.dart';
import 'widgets/greenfield_orders_surface.dart';

class GreenfieldOrdersPage extends StatefulWidget {
  const GreenfieldOrdersPage({super.key, this.modal = false});

  final bool modal;

  @override
  State<GreenfieldOrdersPage> createState() => _GreenfieldOrdersPageState();
}

class _GreenfieldOrdersPageState extends State<GreenfieldOrdersPage> {
  bool _loading = true;
  String? _error;
  List<RemoteOrder> _orders = const [];
  String? _activeTradeNo;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(_load());
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _load();
    if (!mounted || _error != null) return;
    AppToast.show(
      context,
      context.l10n.refreshed,
      type: AppToastType.success,
    );
  }

  Future<void> _payOrder(RemoteOrder order) async {
    if (_activeTradeNo != null) return;
    setState(() => _activeTradeNo = order.tradeNo);
    final controller = AppScope.of(context);
    try {
      await showOrderPaymentDialog(
        context: context,
        tradeNo: order.tradeNo,
        finalPrice: order.totalAmount / 100,
        api: controller.api,
        onPaid: controller.refreshData,
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
      builder: (_) => GreenfieldCancelOrderModal(orderNo: order.tradeNo),
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
    } catch (error) {
      if (!mounted) return;
      AppToast.show(
        context,
        error.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _activeTradeNo = null);
    }
  }

  Widget _body(BuildContext context) {
    if (_loading) return const PageLoadingCard();
    if (_error != null) {
      return PageStateCard(
        icon: LucideIcons.circleAlert,
        title: context.l10n.orderLoadFailed,
        subtitle: AppErrorMessageService.userFacing(_error!, context.l10n),
        onTap: _load,
      );
    }
    if (_orders.isEmpty) {
      return PageStateCard(
        icon: LucideIcons.receipt,
        title: context.l10n.noOrders,
        subtitle: context.l10n.ordersAppearAfterPurchase,
      );
    }

    return GreenfieldOrdersSurface(
      orders: _orders,
      currencySymbol: AppScope.of(context).currencySymbol,
      activeTradeNo: _activeTradeNo,
      onPay: _payOrder,
      onCancel: _cancelOrder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    if (widget.modal) {
      return AppAdaptiveModal(
        title: context.l10n.orders,
        subtitle: context.l10n.orderHistorySubtitle,
        maxWidth: 760,
        maxHeightFactor: 0.86,
        child: body,
      );
    }

    return ResponsivePageScaffold(
      title: context.l10n.orders,
      subtitle: context.l10n.orderHistorySubtitle,
      compactTitle: context.l10n.order,
      compactSubtitle: context.l10n.ordersSubtitle,
      primaryCompact: isPrimaryCompactTab(AppPage.orders),
      onRefresh: _refresh,
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      children: [body],
    );
  }
}

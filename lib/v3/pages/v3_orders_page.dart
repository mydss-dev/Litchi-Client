import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';

class V3OrdersPage extends StatefulWidget {
  const V3OrdersPage({super.key});

  @override
  State<V3OrdersPage> createState() => _V3OrdersPageState();
}

class _V3OrdersPageState extends State<V3OrdersPage> {
  bool _initialized = false;
  bool _loading = true;
  String? _error;
  String? _busyTradeNo;
  List<RemoteOrder> _orders = const [];
  int _filter = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    unawaited(_load());
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final orders = await AppScope.read(context).api.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _pay(RemoteOrder order) async {
    if (_busyTradeNo != null) return;
    final controller = AppScope.read(context);
    setState(() => _busyTradeNo = order.tradeNo);
    try {
      await showV3PaymentFlow(
        context: context,
        tradeNo: order.tradeNo,
        fallbackAmount: order.totalAmount / 100,
        currencySymbol: controller.currencySymbol,
        api: controller.api,
        onPaid: controller.refreshData,
      );
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _busyTradeNo = null);
    }
  }

  Future<void> _cancel(RemoteOrder order) async {
    if (_busyTradeNo != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _CancelOrderDialog(order: order),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyTradeNo = order.tradeNo);
    try {
      await AppScope.read(context).api.cancelOrder(order.tradeNo);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _toast(_message(error));
    } finally {
      if (mounted) setState(() => _busyTradeNo = null);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<RemoteOrder> get _visibleOrders => switch (_filter) {
    1 =>
      _orders.where((order) => order.status == 0 || order.status == 1).toList(),
    2 =>
      _orders.where((order) => order.status == 3 || order.status == 4).toList(),
    3 => _orders.where((order) => order.status == 2).toList(),
    _ => _orders,
  };

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final visible = _visibleOrders;
    final pending = _orders
        .where((order) => order.status == 0 || order.status == 1)
        .length;
    final completed = _orders
        .where((order) => order.status == 3 || order.status == 4)
        .length;
    final spent = _orders
        .where((order) => order.status == 3 || order.status == 4)
        .fold<int>(0, (sum, order) => sum + order.totalAmount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 34,
            26,
            compact ? 20 : 34,
            36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER LEDGER',
                          style: TextStyle(
                            color: p.lycheeInk,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '订单记录',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '购买、支付和取消都在同一条订单链路里完成。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '刷新订单',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              compact
                  ? Column(
                      children: [
                        _OrderMetric(
                          label: '全部订单',
                          value: '${_orders.length}',
                          accent: p.lychee,
                        ),
                        const SizedBox(height: 10),
                        _OrderMetric(
                          label: '待处理',
                          value: '$pending',
                          accent: p.warning,
                        ),
                        const SizedBox(height: 10),
                        _OrderMetric(
                          label: '已完成',
                          value: '$completed',
                          accent: p.success,
                        ),
                        const SizedBox(height: 10),
                        _OrderMetric(
                          label: '累计支付',
                          value:
                              '${controller.currencySymbol}${(spent / 100).toStringAsFixed(2)}',
                          accent: p.aqua,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _OrderMetric(
                            label: '全部订单',
                            value: '${_orders.length}',
                            accent: p.lychee,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OrderMetric(
                            label: '待处理',
                            value: '$pending',
                            accent: p.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OrderMetric(
                            label: '已完成',
                            value: '$completed',
                            accent: p.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OrderMetric(
                            label: '累计支付',
                            value:
                                '${controller.currencySymbol}${(spent / 100).toStringAsFixed(2)}',
                            accent: p.aqua,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('全部')),
                          ButtonSegment(value: 1, label: Text('待处理')),
                          ButtonSegment(value: 2, label: Text('已完成')),
                          ButtonSegment(value: 3, label: Text('已取消')),
                        ],
                        selected: {_filter},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) =>
                            setState(() => _filter = value.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(36),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      _OrderEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: '订单加载失败',
                        subtitle: _error!,
                        actionLabel: '重试',
                        onAction: _load,
                      )
                    else if (visible.isEmpty)
                      _OrderEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: '这里还没有订单',
                        subtitle: _filter == 0
                            ? '购买套餐后，订单会出现在这里。'
                            : '当前筛选条件下没有记录。',
                        actionLabel: _filter == 0 ? '去购买套餐' : null,
                        onAction: _filter == 0
                            ? () => controller.goToPage(AppPage.shop)
                            : null,
                      )
                    else
                      for (var i = 0; i < visible.length; i++) ...[
                        _OrderRow(
                          order: visible[i],
                          currencySymbol: controller.currencySymbol,
                          busy: _busyTradeNo == visible[i].tradeNo,
                          onPay: () => _pay(visible[i]),
                          onCancel: () => _cancel(visible[i]),
                        ),
                        if (i != visible.length - 1)
                          Divider(color: p.line, height: 1),
                      ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 100,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: p.inkMuted, fontSize: 9)),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.currencySymbol,
    required this.busy,
    required this.onPay,
    required this.onCancel,
  });

  final RemoteOrder order;
  final String currencySymbol;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final statusColor = switch (order.status) {
      0 => p.warning,
      1 => p.aqua,
      2 => p.inkMuted,
      3 || 4 => p.success,
      _ => p.inkMuted,
    };
    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim()
        : order.periodLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.tradeNo} · ${order.dateDisplay}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                order.amountDisplay(currencySymbol),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (order.status == 0) ...[
            const SizedBox(width: 12),
            if (busy)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              PopupMenuButton<String>(
                tooltip: '订单操作',
                onSelected: (value) {
                  if (value == 'pay') onPay();
                  if (value == 'cancel') onCancel();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'pay', child: Text('继续支付')),
                  PopupMenuItem(value: 'cancel', child: Text('取消订单')),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ],
      ),
    );
  }
}

class _OrderEmptyState extends StatelessWidget {
  const _OrderEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: p.inkMuted, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 10),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CancelOrderDialog extends StatelessWidget {
  const _CancelOrderDialog({required this.order});

  final RemoteOrder order;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      title: const Text('取消这个订单？'),
      content: Text('订单 ${order.tradeNo} 将被取消。取消后如果还需要该套餐，需要重新创建订单。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('保留订单'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认取消'),
        ),
      ],
    );
  }
}

String _message(Object error) => error
    .toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');

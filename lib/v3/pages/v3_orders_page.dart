import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_sheet.dart';
import '../ui/v3_dialog_frame.dart';
import '../ui/v3_layout.dart';

class V3OrdersPage extends StatefulWidget {
  const V3OrdersPage({super.key});

  /// The sheet owns the title and refresh action. A key connects the action to
  /// the list, without disrupting its first-frame loading skeleton.
  static Future<void> show(BuildContext context) {
    final key = GlobalKey<_V3OrdersPageState>();
    return showV3Sheet<void>(context,
      title: v3Copy(context, zh: '订单记录', en: 'Order history', tw: '訂單紀錄'),
      trailing: IconButton(
        tooltip: v3Copy(context, zh: '刷新订单',
          en: 'Refresh orders', tw: '重新整理訂單'),
        onPressed: () => key.currentState?.refresh(),
        icon: const Icon(Icons.refresh_rounded)),
      builder: (_) => V3OrdersPage(key: key));
  }

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

  void refresh() => unawaited(_load());

  Future<void> _load() async {
    if (mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final orders = await AppScope.read(context).api.fetchOrders();
      if (!mounted) return;
      setState(() { _orders = orders; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = _message(error); });
    }
  }

  Future<void> _pay(RemoteOrder order) async {
    if (_busyTradeNo != null) return;
    final controller = AppScope.read(context);
    setState(() => _busyTradeNo = order.tradeNo);
    try {
      await showV3PaymentFlow(context: context, tradeNo: order.tradeNo,
        fallbackAmount: order.totalAmount / 100,
        currencySymbol: controller.currencySymbol, api: controller.api,
        onPaid: controller.refreshData);
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _busyTradeNo = null);
    }
  }

  Future<void> _cancel(RemoteOrder order) async {
    if (_busyTradeNo != null) return;
    final confirmed = await showDialog<bool>(context: context,
      barrierColor: Colors.black.withValues(alpha: .48),
      builder: (context) => _CancelOrderDialog(order: order));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<RemoteOrder> get _visibleOrders => switch (_filter) {
    1 => _orders.where((order) => order.status == 0 || order.status == 1).toList(),
    2 => _orders.where((order) => order.status == 3 || order.status == 4).toList(),
    3 => _orders.where((order) => order.status == 2).toList(),
    _ => _orders,
  };

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final visible = _visibleOrders;
    final pending = _orders.where(
      (order) => order.status == 0 || order.status == 1).length;
    final completed = _orders.where(
      (order) => order.status == 3 || order.status == 4).length;
    final spent = _orders.where(
      (order) => order.status == 3 || order.status == 4)
      .fold<int>(0, (sum, order) => sum + order.totalAmount);

    final metrics = <Widget>[
      _OrderMetric(label: v3Copy(context, zh: '全部订单',
          en: 'All orders', tw: '全部訂單'),
        value: '${_orders.length}', accent: p.lychee, loading: _loading),
      _OrderMetric(label: v3Copy(context, zh: '待处理',
          en: 'Pending', tw: '待處理'),
        value: '$pending', accent: p.warning, loading: _loading),
      _OrderMetric(label: v3Copy(context, zh: '已完成',
          en: 'Completed', tw: '已完成'),
        value: '$completed', accent: p.success, loading: _loading),
      _OrderMetric(label: v3Copy(context, zh: '累计支付',
          en: 'Total paid', tw: '累計支付'),
        value: '${controller.currencySymbol}${(spent / 100).toStringAsFixed(2)}',
        accent: p.aqua, loading: _loading),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final phone = constraints.maxWidth < 480;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!compact)
          Row(children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: metrics[i]),
            ],
          ])
        else if (!phone)
          Column(children: [
            Row(children: [
              Expanded(child: metrics[0]), const SizedBox(width: 12),
              Expanded(child: metrics[1]),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: metrics[2]), const SizedBox(width: 12),
              Expanded(child: metrics[3]),
            ]),
          ])
        else
          Column(children: [
            Row(children: [
              Expanded(child: metrics[0]), const SizedBox(width: 8),
              Expanded(child: metrics[1]),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: metrics[2]), const SizedBox(width: 8),
              Expanded(child: metrics[3]),
            ]),
          ]),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(V3Layout.cardRadius),
            border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? p.lycheeSoft : p.surfaceRaised),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? p.lycheeInk : p.ink),
                  side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.selected) ? p.lychee : p.line)),
                ),
                segments: [
                  ButtonSegment(value: 0, label: Text(v3Copy(context,
                    zh: '全部', en: 'All', tw: '全部'))),
                  ButtonSegment(value: 1, label: Text(v3Copy(context,
                    zh: '待处理', en: 'Pending', tw: '待處理'))),
                  ButtonSegment(value: 2, label: Text(v3Copy(context,
                    zh: '已完成', en: 'Completed', tw: '已完成'))),
                  ButtonSegment(value: 3, label: Text(v3Copy(context,
                    zh: '已取消', en: 'Cancelled', tw: '已取消'))),
                ],
                selected: {_filter}, showSelectedIcon: false,
                onSelectionChanged: (value) => setState(() => _filter = value.first))),
            const SizedBox(height: 16),
            if (_loading)
              const _OrdersSkeleton()
            else if (_error != null)
              _OrderEmptyState(icon: Icons.error_outline_rounded,
                title: v3Copy(context, zh: '订单加载失败',
                  en: 'Could not load orders', tw: '訂單載入失敗'),
                subtitle: _error!,
                actionLabel: v3Copy(context, zh: '重试',
                  en: 'Retry', tw: '重試'), onAction: _load)
            else if (visible.isEmpty)
              _OrderEmptyState(icon: Icons.receipt_long_rounded,
                title: v3Copy(context, zh: '这里还没有订单',
                  en: 'No orders here yet', tw: '這裡尚無訂單'),
                subtitle: _filter == 0
                  ? v3Copy(context, zh: '购买套餐后，订单会出现在这里。',
                      en: 'Your orders appear here after you buy a plan.',
                      tw: '購買方案後，訂單會顯示在這裡。')
                  : v3Copy(context, zh: '当前筛选条件下没有记录。',
                      en: 'No orders match this filter.', tw: '目前篩選條件下沒有紀錄。'),
                actionLabel: _filter == 0 ? v3Copy(context, zh: '去购买套餐',
                  en: 'Buy a plan', tw: '前往購買方案') : null,
                onAction: _filter == 0 ? () {
                  closeV3Sheet(context);
                  controller.goToPage(AppPage.shop);
                } : null)
            else
              for (var i = 0; i < visible.length; i++) ...[
                _OrderRow(order: visible[i],
                  currencySymbol: controller.currencySymbol,
                  busy: _busyTradeNo == visible[i].tradeNo,
                  onPay: () => _pay(visible[i]),
                  onCancel: () => _cancel(visible[i])),
                if (i != visible.length - 1) Divider(color: p.line, height: 1),
              ],
          ]),
        ),
      ]);
    });
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({required this.label, required this.value,
    required this.accent, this.loading = false});
  final String label;
  final String value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(height: 72, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line)),
      child: Row(children: [
        Container(width: 4, height: 34,
          decoration: BoxDecoration(color: accent,
            borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 8),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
            const SizedBox(height: 4),
            if (loading)
              const V3SkeletonBlock(width: 30, height: 16)
            else Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 16,
                fontWeight: FontWeight.w900)),
          ])),
      ]),
    );
  }
}

class _OrdersSkeleton extends StatelessWidget {
  const _OrdersSkeleton();
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(children: [
      for (var i = 0; i < 3; i++) ...[
        const _OrderSkeletonRow(),
        if (i != 2) Divider(color: p.line, height: 1),
      ],
    ]);
  }
}

class _OrderSkeletonRow extends StatelessWidget {
  const _OrderSkeletonRow();
  @override
  Widget build(BuildContext context) {
    return const Padding(padding: EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        V3SkeletonBlock(width: 44, height: 44, radius: 15),
        SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FractionallySizedBox(widthFactor: .7,
              alignment: Alignment.centerLeft,
              child: V3SkeletonBlock(height: 12)),
            SizedBox(height: 7),
            FractionallySizedBox(widthFactor: .45,
              alignment: Alignment.centerLeft,
              child: V3SkeletonBlock(height: 9)),
          ])),
        SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          V3SkeletonBlock(width: 44, height: 12),
          SizedBox(height: 7),
          V3SkeletonBlock(width: 30, height: 9),
        ]),
      ]));
  }
}

String _statusLabel(BuildContext context, RemoteOrder order) => switch (order.status) {
  0 => v3Copy(context, zh: order.statusLabel,
    en: 'Unpaid', tw: '待付款'),
  1 => v3Copy(context, zh: order.statusLabel,
    en: 'Pending', tw: '待處理'),
  2 => v3Copy(context, zh: order.statusLabel,
    en: 'Cancelled', tw: '已取消'),
  3 || 4 => v3Copy(context, zh: order.statusLabel,
    en: 'Completed', tw: '已完成'),
  _ => order.statusLabel,
};

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.currencySymbol,
    required this.busy, required this.onPay, required this.onCancel});
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
        ? order.planName!.trim() : order.periodLabel;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(15)),
          child: Icon(Icons.receipt_long_rounded,
            color: statusColor, size: 20)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 12,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${order.tradeNo} · ${order.dateDisplay}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 10)),
          ])),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(order.amountDisplay(currencySymbol),
            style: TextStyle(color: p.ink, fontSize: 12,
              fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(_statusLabel(context, order),
            style: TextStyle(color: statusColor, fontSize: 10,
              fontWeight: FontWeight.w800)),
        ]),
        if (order.status == 0) ...[
          const SizedBox(width: 12),
          if (busy)
            const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          else PopupMenuButton<String>(
            tooltip: v3Copy(context, zh: '订单操作',
              en: 'Order actions', tw: '訂單操作'),
            onSelected: (value) {
              if (value == 'pay') onPay();
              if (value == 'cancel') onCancel();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pay', child: Text(v3Copy(context,
                zh: '继续支付', en: 'Continue payment', tw: '繼續付款'))),
              PopupMenuItem(value: 'cancel', child: Text(v3Copy(context,
                zh: '取消订单', en: 'Cancel order', tw: '取消訂單'))),
            ],
            icon: const Icon(Icons.more_horiz_rounded)),
        ],
      ]));
  }
}

class _OrderEmptyState extends StatelessWidget {
  const _OrderEmptyState({required this.icon, required this.title,
    required this.subtitle, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 34),
      child: Center(child: Column(children: [
        Icon(icon, color: p.inkMuted, size: 28),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(color: p.ink,
          fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: p.inkMuted, fontSize: 10)),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ])));
  }
}

class _CancelOrderDialog extends StatelessWidget {
  const _CancelOrderDialog({required this.order});
  final RemoteOrder order;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: v3DialogShape(p),
      title: Text(v3Copy(context, zh: '取消这个订单？',
        en: 'Cancel this order?', tw: '取消這筆訂單？')),
      content: Text(v3Copy(context,
        zh: '订单 ${order.tradeNo} 将被取消。取消后如果还需要该套餐，需要重新创建订单。',
        en: 'Order ${order.tradeNo} will be cancelled. Create another order if you still want the plan.',
        tw: '訂單 ${order.tradeNo} 將被取消。如仍需此方案，請重新建立訂單。')),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false),
          child: Text(v3Copy(context, zh: '保留订单',
            en: 'Keep order', tw: '保留訂單'))),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: p.danger,
            foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(v3Copy(context, zh: '确认取消',
            en: 'Confirm cancellation', tw: '確認取消'))),
      ]);
  }
}

String _message(Object error) => error.toString()
    .replaceFirst('ApiException: ', '')
    .replaceFirst('Exception: ', '');
import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_sheet.dart';
import '../ui/v3_toast.dart';

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
  // The panel API returns the full ledger in one call, so pagination is
  // client-side: render the first page and grow on demand.
  static const _pageSize = 10;
  bool _initialized = false;
  bool _loading = true;
  String? _error;
  String? _busyTradeNo;
  List<RemoteOrder> _orders = const [];
  int _filter = 0;
  int _limit = _pageSize;

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
    V3Toast.show(context, message, type: V3ToastType.error);
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
    final shown = visible.take(_limit).toList(growable: false);
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
      final compact = constraints.maxWidth < V3Layout.paneCompact;
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
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              metrics[i],
            ],
          ]),
        const SizedBox(height: 16),
        Container(width: double.infinity, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: p.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
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
                onSelectionChanged: (value) => setState(() {
                  _filter = value.first;
                  _limit = _pageSize;
                }))),
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
            else ...[
              for (var i = 0; i < shown.length; i++) ...[
                _OrderRow(order: shown[i],
                  currencySymbol: controller.currencySymbol,
                  wide: constraints.maxWidth >= V3Layout.paneCompact,
                  busy: _busyTradeNo == shown[i].tradeNo,
                  onPay: () => _pay(shown[i]),
                  onCancel: () => _cancel(shown[i])),
                if (i != shown.length - 1) Divider(color: p.line, height: 1),
              ],
              if (visible.length > shown.length) ...[
                const SizedBox(height: 4),
                Center(child: TextButton(
                  onPressed: () => setState(() => _limit += _pageSize),
                  child: Text(v3Copy(context,
                    zh: '显示更多订单（剩余 ${visible.length - shown.length} 条）',
                    en: 'Show more (${visible.length - shown.length} remaining)',
                    tw: '顯示更多訂單（剩餘 ${visible.length - shown.length} 筆）')))),
              ],
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
    return Container(height: 100, padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Container(width: 4, height: 48,
          decoration: BoxDecoration(color: accent,
            borderRadius: BorderRadius.circular(8))),
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10)),
            const SizedBox(height: 4),
            if (loading)
              const V3SkeletonBlock(width: 30, height: 16)
            else Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 18,
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
  // The row layout follows its container width (`wide`), not the window
  // width: inside the 560dp order sheet the wide layout would not fit.
  const _OrderRow({required this.order, required this.currencySymbol,
    required this.wide, required this.busy, required this.onPay,
    required this.onCancel});
  final RemoteOrder order;
  final String currencySymbol;
  final bool wide;
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
    if (!wide) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 13,
                fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Text(_statusLabel(context, order),
              style: TextStyle(color: statusColor, fontSize: 10,
                fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          Text('${order.tradeNo} · ${order.dateDisplay}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.inkMuted, fontSize: 10)),
          const SizedBox(height: 8),
          Text(order.amountDisplay(currencySymbol),
            style: TextStyle(color: p.ink, fontSize: 15,
              fontWeight: FontWeight.w900)),
          if (order.status == 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : onCancel,
                child: Text(v3Copy(context, zh: '取消订单',
                  en: 'Cancel order', tw: '取消訂單')))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                onPressed: busy ? null : onPay,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: Colors.white),
                child: busy ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    color: Colors.white))
                  : Text(v3Copy(context, zh: '继续支付',
                    en: 'Continue payment', tw: '繼續付款')))),
            ]),
          ],
        ]));
    }
    // Ledger row for wide containers: plan | trade no & date | amount |
    // status | inline actions. Pending-order actions are visible buttons
    // instead of the compact row's overflow menu, so desktop users see what
    // an unpaid order can do without an extra click.
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
        Text(order.amountDisplay(currencySymbol),
          style: TextStyle(color: p.ink, fontSize: 13,
            fontWeight: FontWeight.w900)),
        const SizedBox(width: 12),
        Text(_statusLabel(context, order),
          style: TextStyle(color: statusColor, fontSize: 10,
            fontWeight: FontWeight.w800)),
        if (order.status == 0) ...[
          const SizedBox(width: 12),
          if (busy)
            const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            SizedBox(height: 34, child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: p.inkMuted,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700)),
              child: Text(v3Copy(context, zh: '取消订单',
                en: 'Cancel order', tw: '取消訂單')))),
            const SizedBox(width: 8),
            SizedBox(height: 34, child: FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700)),
              child: Text(v3Copy(context, zh: '继续支付',
                en: 'Continue payment', tw: '繼續付款')))),
          ],
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
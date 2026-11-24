import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/api_client.dart';
import '../commerce/v3_payment_flow.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
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
      // Two-character page title per the secondary-page ruling.
      title: v3Copy(context, zh: '订单', en: 'Orders', tw: '訂單'),
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
  bool _loadInFlight = false;
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
    // Single-flight: rapid refresh taps must not fire concurrent fetches whose
    // completion order is nondeterministic (round-3 audit F23).
    if (_loadInFlight) return;
    _loadInFlight = true;
    if (mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final orders = await AppScope.read(context).api.fetchOrders();
      if (!mounted) return;
      setState(() { _orders = orders; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiNotConfiguredException) {
        // Setup stage: a neutral empty ledger, not a failure to retry.
        setState(() { _orders = const []; _loading = false; });
      } else {
        setState(() { _loading = false; _error = v3UserFacingError(context, error); });
      }
    } finally {
      _loadInFlight = false;
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
    // The shared destructive guard: identical geometry and danger styling to
    // every other confirm, with "keep order" spelled out so it cannot read as
    // dismissing the dialog (round-3 audit F16).
    final confirmed = await showV3ConfirmDialog(context,
      title: v3Copy(context, zh: '取消这个订单？',
        en: 'Cancel this order?', tw: '取消這筆訂單？'),
      body: v3Copy(context,
        zh: '订单 ${order.tradeNo} 将被取消。取消后如果还需要该套餐，需要重新创建订单。',
        en: 'Order ${order.tradeNo} will be cancelled. Create another order if you still want the plan.',
        tw: '訂單 ${order.tradeNo} 將被取消。如仍需此方案，請重新建立訂單。'),
      confirmLabel: v3Copy(context, zh: '取消订单',
        en: 'Cancel order', tw: '取消訂單'),
      destructive: true,
      cancelLabel: v3Copy(context, zh: '保留订单',
        en: 'Keep order', tw: '保留訂單'));
    if (!confirmed || !mounted) return;
    setState(() => _busyTradeNo = order.tradeNo);
    try {
      await AppScope.read(context).api.cancelOrder(order.tradeNo);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) _toast(v3UserFacingError(context, error));
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


  Future<void> _openOrder(RemoteOrder order) async {
    final controller = AppScope.read(context);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MobileOrderDetail(
          order: order,
          currencySymbol: controller.currencySymbol,
          loadDetails: () => controller.api.getOrderPaymentDetail(order.tradeNo),
          onPay: () => _pay(order),
          onCancel: () => _cancel(order),
        ),
      ),
    );
    if (mounted) await _load();
  }

  /// Mobile ledger matches the reference: segmented filter and one list card.
  Widget _mobileBody(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final visible = _visibleOrders;
    final shown = visible.take(_limit).toList(growable: false);
    final filters = [
      v3Copy(context, zh: '全部', en: 'All', tw: '全部'),
      v3Copy(context, zh: '待处理', en: 'Pending', tw: '待處理'),
      v3Copy(context, zh: '已完成', en: 'Completed', tw: '已完成'),
      v3Copy(context, zh: '已取消', en: 'Cancelled', tw: '已取消'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(children: [
          for (var i = 0; i < filters.length; i++)
            Expanded(child: Semantics(
              button: true,
              selected: _filter == i,
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: () => setState(() {
                  _filter = i;
                  _limit = _pageSize;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _filter == i ? p.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(filters[i], maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _filter == i ? p.ink : p.inkMuted,
                      fontSize: 12,
                      fontWeight: _filter == i
                          ? FontWeight.w700 : FontWeight.w500,
                    )),
                ),
              ),
            )),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(
          v3Copy(context, zh: '订单列表 · ${visible.length} 笔',
              en: '${visible.length} orders',
              tw: '訂單列表 · ${visible.length} 筆'),
          style: TextStyle(color: p.inkMuted, fontSize: 12))),
        IconButton(
          tooltip: v3Copy(context, zh: '刷新订单',
              en: 'Refresh orders', tw: '重新整理訂單'),
          onPressed: _loading ? null : refresh,
          icon: Icon(Icons.refresh_rounded, color: p.inkMuted, size: 19),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ]),
      const SizedBox(height: 5),
      if (_loading)
        const _OrdersSkeleton()
      else if (_error != null)
        V3EmptyState(
          icon: Icons.error_outline_rounded,
          title: v3Copy(context, zh: '订单加载失败',
            en: 'Could not load orders', tw: '訂單載入失敗'),
          subtitle: _error!,
          actionLabel: v3Copy(context, zh: '重试',
            en: 'Retry', tw: '重試'),
          onAction: _load,
        )
      else if (visible.isEmpty)
        V3EmptyState(
          icon: Icons.receipt_long_outlined,
          title: v3Copy(context, zh: '暂无订单',
            en: 'No orders', tw: '暫無訂單'),
          subtitle: _filter == 0
              ? v3Copy(context,
                  zh: '购买套餐后，订单会出现在这里。',
                  en: 'Your orders appear here after a purchase.',
                  tw: '購買方案後，訂單會顯示在這裡。')
              : v3Copy(context,
                  zh: '没有符合当前筛选条件的订单。',
                  en: 'No orders match this filter.',
                  tw: '沒有符合目前篩選條件的訂單。'),
          actionLabel: _filter == 0
              ? v3Copy(context, zh: '查看套餐',
                  en: 'Browse plans', tw: '查看套餐')
              : null,
          onAction: _filter == 0
              ? () => controller.goToPage(AppPage.shop) : null,
        )
      else
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: p.hairline),
          ),
          child: Column(children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Divider(color: p.line, height: 1),
                ),
              _MobileOrderRow(
                order: shown[i],
                currencySymbol: controller.currencySymbol,
                onTap: () => _openOrder(shown[i]),
              ),
            ],
          ]),
        ),
      if (visible.length > shown.length) ...[
        const SizedBox(height: 12),
        Center(child: TextButton(
          onPressed: () => setState(() => _limit += _pageSize),
          child: Text(v3Copy(context,
            zh: '加载更多（剩余 ${visible.length - shown.length} 笔）',
            en: 'Load more (${visible.length - shown.length})',
            tw: '載入更多（剩餘 ${visible.length - shown.length} 筆）')),
        )),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // The reference design presents phone orders as one readable ledger.
    // The desktop table keeps its existing summary and layout.
    if (MediaQuery.sizeOf(context).width < 480) {
      return _mobileBody(context);
    }
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
      V3MetricTile(label: v3Copy(context, zh: '全部订单',
          en: 'All orders', tw: '全部訂單'),
        value: '${_orders.length}', accent: p.lychee, loading: _loading),
      V3MetricTile(label: v3Copy(context, zh: '待处理',
          en: 'Pending', tw: '待處理'),
        value: '$pending', accent: p.warning, loading: _loading),
      V3MetricTile(label: v3Copy(context, zh: '已完成',
          en: 'Completed', tw: '已完成'),
        value: '$completed', accent: p.success, loading: _loading),
      V3MetricTile(label: v3Copy(context, zh: '已完成金额',
          en: 'Completed amount', tw: '已完成金額'),
        value: '${controller.currencySymbol}${(spent / 100).toStringAsFixed(2)}',
        accent: p.aqua, loading: _loading),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < V3Layout.paneCompact;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Full-page account navigation needs its own refresh affordance.
        // The legacy sheet already has one in its header.
        if (ModalRoute.of(context)?.isFirst ?? true) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : refresh,
              style: TextButton.styleFrom(foregroundColor: p.inkMuted),
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: Text(v3Copy(context,
                zh: '刷新订单', en: 'Refresh', tw: '重新整理訂單')),
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (!compact)
          Row(children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: metrics[i]),
            ],
          ])
        else
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
          ]),
        const SizedBox(height: 16),
        // Stacked long cards (Elegant reference): every order is its own
        // rounded surface with generous padding, not a divided list inside
        // one panel.
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(V3Radius.card),
            boxShadow: p.shadows),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal,
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
              })))),
        const SizedBox(height: 12),
        if (_loading)
          const _OrdersSkeleton()
        else if (_error != null)
          V3EmptyState(icon: Icons.error_outline_rounded,
            title: v3Copy(context, zh: '订单加载失败',
              en: 'Could not load orders', tw: '訂單載入失敗'),
            subtitle: _error!,
            actionLabel: v3Copy(context, zh: '重试',
              en: 'Retry', tw: '重試'), onAction: _load)
        else if (visible.isEmpty)
          V3EmptyState(icon: Icons.receipt_long_rounded,
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
            if (i > 0) const SizedBox(height: 12),
            Container(width: double.infinity, padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: p.surface,
                borderRadius: BorderRadius.circular(V3Radius.card),
                boxShadow: p.shadows),
              child: _OrderRow(order: shown[i],
                currencySymbol: controller.currencySymbol,
                wide: constraints.maxWidth >= V3Layout.paneCompact,
                busy: _busyTradeNo == shown[i].tradeNo,
                onPay: () => _pay(shown[i]),
                onCancel: () => _cancel(shown[i]))),
          ],
          if (visible.length > shown.length) ...[
            const SizedBox(height: 8),
            Center(child: TextButton(
              onPressed: () => setState(() => _limit += _pageSize),
              child: Text(v3Copy(context,
                zh: '显示更多订单（剩余 ${visible.length - shown.length} 条）',
                en: 'Show more (${visible.length - shown.length} remaining)',
                tw: '顯示更多訂單（剩餘 ${visible.length - shown.length} 筆）')))),
          ],
        ],
      ]);
    });
  }
}


/// The entire order row is the hit target; details are a real Android route,
/// not a static card or an invisible chevron with no action.
class _MobileOrderRow extends StatelessWidget {
  const _MobileOrderRow({
    required this.order,
    required this.currencySymbol,
    required this.onTap,
  });

  final RemoteOrder order;
  final String currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final statusColor = switch (order.status) {
      0 || 1 => p.warningInk,
      3 || 4 => p.successInk,
      _ => p.inkMuted,
    };
    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim() : order.periodLabel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('v3-order-row-${order.tradeNo}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Text(order.tradeNo, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()])),
                const SizedBox(height: 8),
                Text(_statusLabel(context, order),
                  style: TextStyle(color: statusColor, fontSize: 11,
                    fontWeight: FontWeight.w700)),
              ],
            )),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(order.amountDisplay(currencySymbol),
                style: TextStyle(color: p.ink, fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 5),
              Text(order.dateDisplay,
                style: TextStyle(color: p.inkMuted, fontSize: 11)),
            ]),
            const SizedBox(width: 5),
            Icon(Icons.chevron_right_rounded, size: 17,
              color: p.inkMuted),
          ]),
        ),
      ),
    );
  }
}

class _MobileOrderDetail extends StatefulWidget {
  const _MobileOrderDetail({
    required this.order,
    required this.currencySymbol,
    required this.loadDetails,
    required this.onPay,
    required this.onCancel,
  });

  final RemoteOrder order;
  final String currencySymbol;
  final Future<RemoteOrderPaymentDetail> Function() loadDetails;
  final Future<void> Function() onPay;
  final Future<void> Function() onCancel;

  @override
  State<_MobileOrderDetail> createState() => _MobileOrderDetailState();
}

class _MobileOrderDetailState extends State<_MobileOrderDetail> {
  late Future<RemoteOrderPaymentDetail> _details;
  bool _busy = false;
  int? _latestStatus;

  Future<RemoteOrderPaymentDetail> _loadDetail() async {
    final detail = await widget.loadDetails();
    if (mounted && _latestStatus != detail.status) {
      setState(() => _latestStatus = detail.status);
    }
    return detail;
  }

  @override
  void initState() {
    super.initState();
    _details = _loadDetail();
  }

  Future<void> _execute(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) setState(() => _details = _loadDetail());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(BuildContext context, String title, String value) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 95,
          child: Text(title, style: TextStyle(
            fontSize: 12, color: p.inkMuted))),
        Expanded(child: SelectableText(value,
          style: TextStyle(color: p.ink, fontSize: 13,
            fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _money(int cents) =>
      '${widget.currencySymbol}${(cents / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final order = widget.order;
    final displayOrder = RemoteOrder(
      tradeNo: order.tradeNo,
      planName: order.planName,
      period: order.period,
      totalAmount: order.totalAmount,
      status: _latestStatus ?? order.status,
      createdAt: order.createdAt,
    );
    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim() : order.periodLabel;
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: v3Copy(context, zh: '返回订单列表',
            en: 'Back to orders', tw: '返回訂單列表'),
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: p.ink),
        ),
        title: Text(v3Copy(context, zh: '订单详情',
          en: 'Order details', tw: '訂單詳情'),
          style: TextStyle(color: p.ink, fontSize: 21,
            fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusLabel(context, displayOrder), style: TextStyle(
                      color: displayOrder.status == 3 || displayOrder.status == 4
                          ? p.successInk : p.inkMuted,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Text(widget.order.amountDisplay(widget.currencySymbol),
                      style: TextStyle(color: p.ink,
                        fontSize: 30, fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(height: 8),
                    Text(title, style: TextStyle(
                      color: p.inkMuted, fontSize: 13)),
                  ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 5),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(color: p.hairline),
                ),
                child: Column(children: [
                  _field(context,
                    v3Copy(context, zh: '订单编号',
                      en: 'Order number', tw: '訂單編號'),
                    order.tradeNo),
                  Divider(color: p.line, height: 1),
                  _field(context,
                    v3Copy(context, zh: '套餐',
                      en: 'Plan', tw: '方案'),
                    title),
                  Divider(color: p.line, height: 1),
                  _field(context,
                    v3Copy(context, zh: '购买周期',
                      en: 'Billing period', tw: '購買週期'),
                    order.periodLabel),
                  Divider(color: p.line, height: 1),
                  _field(context,
                    v3Copy(context, zh: '创建日期',
                      en: 'Created', tw: '建立日期'),
                    order.dateDisplay),
                  Divider(color: p.line, height: 1),
                  _field(context,
                    v3Copy(context, zh: '订单金额',
                      en: 'Order total', tw: '訂單金額'),
                    order.amountDisplay(widget.currencySymbol)),
                ]),
              ),
              const SizedBox(height: 16),
              FutureBuilder<RemoteOrderPaymentDetail>(
                future: _details,
                builder: (ctx, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ));
                  }
                  if (!snap.hasData) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(v3Copy(context,
                        zh: '支付明细暂时不可用，以上订单信息仍可查看。',
                        en: 'Payment breakdown is unavailable.',
                        tw: '付款明細暫時無法取得。'),
                        style: TextStyle(color: p.inkMuted, fontSize: 12)),
                    );
                  }
                  final d = snap.data!;
                  final extra = <(String, int?)>[
                    (v3Copy(context, zh: '优惠金额',
                      en: 'Discount', tw: '優惠金額'), d.discountAmount),
                    (v3Copy(context, zh: '套餐折抵',
                      en: 'Subscription credit', tw: '方案折抵'),
                      d.surplusAmount),
                    (v3Copy(context, zh: '余额抵扣',
                      en: 'Wallet balance', tw: '餘額抵扣'), d.balanceAmount),
                    (v3Copy(context, zh: '退款金额',
                      en: 'Refund', tw: '退款金額'), d.refundAmount),
                    (v3Copy(context, zh: '支付手续费',
                      en: 'Payment fee', tw: '付款手續費'),
                      d.preHandlingAmount),
                    (v3Copy(context, zh: '待支付金额',
                      en: 'Amount due', tw: '待付款金額'), d.totalAmount),
                  ].where((entry) => entry.$2 != null).toList();
                  if (extra.isEmpty) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: p.hairline),
                    ),
                    child: Column(children: [
                      for (var i = 0; i < extra.length; i++) ...[
                        if (i > 0) Divider(color: p.line, height: 1),
                        _field(context, extra[i].$1, _money(extra[i].$2!)),
                      ],
                    ]),
                  );
                },
              ),
              if (displayOrder.status == 0) ...[
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: _busy ? null
                        : () => _execute(widget.onCancel),
                    child: Text(v3Copy(context,
                      zh: '取消订单', en: 'Cancel order', tw: '取消訂單')),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(
                    onPressed: _busy ? null
                        : () => _execute(widget.onPay),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.lychee,
                      foregroundColor: p.onLychee),
                    child: Text(v3Copy(context,
                      zh: '继续支付', en: 'Pay now', tw: '繼續付款')),
                  )),
                ]),
              ],
            ],
          ),
        ),
      ),
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
        V3SkeletonBlock(width: 44, height: 44, radius: V3Radius.field),
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
    // Status text renders at 10px, so this map yields the *Ink variants —
    // the base fills (aqua worst of all) miss 4.5:1 against light surfaces.
    final statusColor = switch (order.status) {
      0 || 1 => p.warningInk,
      2 => p.inkMuted,
      3 || 4 => p.successInk,
      _ => p.inkMuted,
    };
    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim() : order.periodLabel;
    if (!wide) {
      return Padding(padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 13,
                fontWeight: FontWeight.w800))),
            const SizedBox(width: 10),
            Text(_statusLabel(context, order),
              style: TextStyle(color: statusColor, fontSize: 11,
                fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 7),
          Text('${order.tradeNo} · ${order.dateDisplay}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.inkMuted, fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Text(order.amountDisplay(currencySymbol),
            style: TextStyle(color: p.ink, fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()])),
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
                  foregroundColor: p.onLychee),
                child: busy ? SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    color: p.onLychee))
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
    return Padding(padding: EdgeInsets.zero,
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(V3Radius.field)),
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
              style: TextStyle(color: p.inkMuted, fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()])),
          ])),
        const SizedBox(width: 12),
        Text(order.amountDisplay(currencySymbol),
          style: TextStyle(color: p.ink, fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(width: 12),
        Text(_statusLabel(context, order),
          style: TextStyle(color: statusColor, fontSize: 11,
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
                  borderRadius: BorderRadius.circular(V3Radius.control)),
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
                foregroundColor: p.onLychee,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(V3Radius.control)),
                textStyle: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700)),
              child: Text(v3Copy(context, zh: '继续支付',
                en: 'Continue payment', tw: '繼續付款')))),
          ],
        ],
      ]));
  }
}


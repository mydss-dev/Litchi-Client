from pathlib import Path

def edit(file, old, new):
    path = Path(file)
    source = path.read_text(encoding='utf8')
    n = source.count(old)
    if n != 1:
        raise RuntimeError(f'{file}: expected 1 anchor, got {n}: {old[:80]}')
    path.write_text(source.replace(old, new, 1), encoding='utf8')

A='lib/v3/auth/v3_auth_view.dart'
edit(A,"import '../ui/v3_locale_copy.dart';","import '../ui/v3_locale_copy.dart';\nimport '../ui/v3_toast.dart';")
edit(A,'  void initState() { super.initState(); _loadSaved(); }', '''  void initState() {
    super.initState();
    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = AppScope.read(context);
      final message = ctrl.startupMessage;
      if (message == null || message.trim().isEmpty) return;
      ctrl.clearStartupMessage();
      V3Toast.show(context, message, type: V3ToastType.warning);
    });
  }''')

T='lib/v3/pages/v3_traffic_page.dart'
edit(T,"import '../../shared/models/app_models.dart';","import '../../shared/models/app_models.dart';\nimport '../../shared/utils/traffic_summary_text.dart';")
edit(T, '  int _days = 7;\n', '''  int _days = 7;
  final ScrollController _trendScroll = ScrollController();
  String? _lastTrendKey;

  @override
  void dispose() {
    _trendScroll.dispose();
    super.dispose();
  }

  void _scrollToLatest(TrafficHistorySeries series) {
    if (series.days.isEmpty) return;
    final day = series.days.last.date;
    final key = '$_days:${series.days.length}:${day.year}-${day.month}-${day.day}';
    if (_lastTrendKey == key) return;
    _lastTrendKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _trendScroll.hasClients) {
        _trendScroll.jumpTo(_trendScroll.position.maxScrollExtent);
      }
    });
  }
''')
edit(T,'    final traffic = controller.traffic;\n    final usedRatio =', '    _scrollToLatest(series);\n    final traffic = controller.traffic;\n    final usedRatio =')
edit(T,'            usagePoints: controller.trafficUsage,\n            onPeriodChanged:', '            usagePoints: controller.trafficUsage,\n            scrollController: _trendScroll,\n            onPeriodChanged:')
edit(T, '    final resetDays = _daysUntilReset(controller.resetDay);', '''    final resetDays = _daysUntilReset(controller.resetDay);
    final expiry = subscriptionExpiryDisplay(
      expiredAt: controller.expiredAt, expiryText: controller.user.expiry);
    final days = expiry.days;''')
edit(T, "          accent: p.lychee),\n        _TimingRow(icon: Icons.event_available_rounded,", '''          accent: p.lychee),
        _TimingRow(icon: Icons.compare_arrows_rounded,
          label: v3Copy(context, zh: '昨日对比', en: 'Vs. yesterday',
            tw: '昨日對比'),
          value: yesterdayComparisonText(context,
            usage: controller.trafficUsage,
            currentGb: controller.todayTrafficGb), accent: p.aqua),
        _TimingRow(icon: Icons.event_available_rounded,''')
edit(T, '          value: controller.planExpiryLabel, accent: p.aqua),', '''          value: controller.planExpiryLabel, accent: p.aqua),
        if (days != null) _TimingRow(icon: Icons.hourglass_bottom_rounded,
          label: v3Copy(context, zh: '距离到期', en: 'Time remaining',
            tw: '距離到期'),
          value: days < 0 ? v3Copy(context, zh: '已过期', en: 'Expired',
            tw: '已過期') : days == 0
            ? v3Copy(context, zh: '今天到期', en: 'Expires today',
              tw: '今天到期')
            : v3Copy(context, zh: '$days 天', en: '$days days',
              tw: '$days 天'), accent: days <= 0 ? p.warning : p.aqua),''')
edit(T, '    required this.usagePoints, required this.onPeriodChanged});',
        '    required this.usagePoints, required this.onPeriodChanged,\n    required this.scrollController});')
edit(T, '  final ValueChanged<int> onPeriodChanged;\n\n  @override\n  Widget build(BuildContext context) {\n    final p = V3Palette.of(context);\n    return Container(width: double.infinity, padding: const EdgeInsets.all(18),',
        '  final ValueChanged<int> onPeriodChanged;\n  final ScrollController scrollController;\n\n  @override\n  Widget build(BuildContext context) {\n    final p = V3Palette.of(context);\n    return Container(width: double.infinity, padding: const EdgeInsets.all(18),')
edit(T, '                return SingleChildScrollView(scrollDirection: Axis.horizontal,\n                  child: SizedBox(width: width,',
        '                return SingleChildScrollView(scrollDirection: Axis.horizontal,\n                  controller: scrollController,\n                  child: SizedBox(width: width,')

O='lib/v3/pages/v3_orders_page.dart'
edit(O, '    return Padding(padding: const EdgeInsets.symmetric(vertical: 15),\n      child: Row(children: [\n        Container(width: 44, height: 44,', '''    if (MediaQuery.sizeOf(context).width < 600) {
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
    return Padding(padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(children: [
        Container(width: 44, height: 44,''')

K='lib/v3/pages/v3_tickets_page.dart'
edit(K, '    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,\n      child: SizedBox(height: kV3TicketRowHeight,', '''    if (MediaQuery.sizeOf(context).width < 600) {
      return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: SizedBox(height: 102,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(ticket.subject.trim().isEmpty
                      ? v3Copy(context, zh: '未命名工单', en: 'Untitled ticket',
                        tw: '未命名工單') : ticket.subject,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 13,
                      fontWeight: FontWeight.w800))),
                  const SizedBox(width: 9),
                  Text(v3Copy(context, zh: ticket.statusLabel,
                    en: ticket.isOpen ? 'Open' : 'Closed',
                    tw: ticket.isOpen ? '處理中' : '已關閉'),
                    style: TextStyle(color: statusColor, fontSize: 10,
                      fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 9),
                Row(children: [
                  Text(levelLabel, style: TextStyle(color: levelColor,
                    fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 9),
                  Expanded(child: Text('#${ticket.id} · ${ticket.dateDisplay}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: p.inkMuted, fontSize: 10))),
                ]),
              ]))));
    }
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,
      child: SizedBox(height: kV3TicketRowHeight,''')

D='lib/v3/pages/v3_dashboard_page.dart'
edit(D,"import '../ui/v3_node_picker.dart';","import '../ui/v3_node_picker.dart';\nimport '../ui/v3_toast.dart';")
edit(D,'                      // Persistent alert and retry are driven by core state.\n                      await controller.toggleConnection();', '''                      // Failure remains a persistent alert with a retry action.
                      final error = await controller.toggleConnection();
                      if (error == null && context.mounted &&
                          controller.connectionStatus == ConnectionStatus.connected) {
                        V3Toast.show(context, v3Copy(context,
                          zh: '连接成功', en: 'Connected', tw: '連線成功'),
                          type: V3ToastType.success);
                      }''')
edit(D, '''        onPressed: () async {
          final error = await controller.setProxyMode(mode);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          }
        },''', '''        onPressed: () async {
          if (active) return;
          final error = await controller.setProxyMode(mode);
          if (!context.mounted) return;
          if (error != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          } else {
            V3Toast.show(context, v3Copy(context,
              zh: '已切换到${_modeTitle(context, mode)}',
              en: 'Switched to ${_modeTitle(context, mode)}',
              tw: '已切換至${_modeTitle(context, mode)}'),
              type: V3ToastType.success);
          }
        },''')
print('Updated five V3 files with six legacy UX improvements')

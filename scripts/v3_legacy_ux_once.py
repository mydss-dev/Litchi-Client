from pathlib import Path


def replace(path, old, new, label):
    file = Path(path)
    source = file.read_text(encoding='utf-8')
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match in {path}, got {count}')
    file.write_text(source.replace(old, new, 1), encoding='utf-8')
    print(f'Applied {label}')


AUTH = 'lib/v3/auth/v3_auth_view.dart'
replace(AUTH,
    "import '../ui/v3_locale_copy.dart';\n",
    "import '../ui/v3_locale_copy.dart';\nimport '../ui/v3_toast.dart';\n",
    'auth toast import')
replace(AUTH,
    '  void initState() { super.initState(); _loadSaved(); }\n',
    '''  void initState() {
    super.initState();
    _loadSaved();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = AppScope.read(context);
      final message = controller.startupMessage;
      if (message == null || message.trim().isEmpty) return;
      controller.clearStartupMessage();
      V3Toast.show(context, message, type: V3ToastType.warning);
    });
  }
''',
    'one-time session-expiry warning')

TRAFFIC = 'lib/v3/pages/v3_traffic_page.dart'
replace(TRAFFIC,
    "import '../../shared/models/app_models.dart';\n",
    "import '../../shared/models/app_models.dart';\nimport '../../shared/utils/traffic_summary_text.dart';\n",
    'traffic formatting import')
replace(TRAFFIC,
    '''    final resetDays = _daysUntilReset(controller.resetDay);
    return Container(padding: const EdgeInsets.all(20),''',
    '''    final resetDays = _daysUntilReset(controller.resetDay);
    final expiry = subscriptionExpiryDisplay(
      expiredAt: controller.expiredAt,
      expiryText: controller.user.expiry,
    );
    final comparison = yesterdayComparisonText(context,
      usage: controller.trafficUsage, currentGb: controller.todayTrafficGb);
    return Container(padding: const EdgeInsets.all(20),''',
    'traffic comparison and expiry data')
replace(TRAFFIC,
    '''          value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB',
          accent: p.lychee),
        _TimingRow(icon: Icons.event_available_rounded,''',
    '''          value: '${controller.todayTrafficGb.toStringAsFixed(2)} GB',
          accent: p.lychee),
        Padding(padding: const EdgeInsets.only(left: 39, bottom: 11),
          child: Text(comparison,
            key: const Key('v3-traffic-yesterday-comparison'),
            style: TextStyle(color: p.inkMuted, fontSize: 10))),
        _TimingRow(icon: Icons.event_available_rounded,''',
    'visible yesterday comparison')
replace(TRAFFIC,
    '''          value: controller.planExpiryLabel, accent: p.aqua),
        _TimingRow(icon: Icons.restart_alt_rounded,''',
    '''          value: controller.planExpiryLabel, accent: p.aqua),
        if (expiry.days != null)
          Padding(padding: const EdgeInsets.only(left: 39, bottom: 11),
            child: Text(expiry.days == 0
              ? v3Copy(context, zh: '到期日已到，请查看套餐状态',
                  en: 'Expiry date reached; check your plan status',
                  tw: '到期日已到，請查看方案狀態')
              : v3Copy(context, zh: '距离到期还有 ${expiry.days} 天',
                  en: '${expiry.days} days until expiry',
                  tw: '距離到期還有 ${expiry.days} 天'),
              key: const Key('v3-traffic-expiry-countdown'),
              style: TextStyle(color: expiry.days! <= 7
                ? p.warningInk : p.inkMuted, fontSize: 10))),
        _TimingRow(icon: Icons.restart_alt_rounded,''',
    'visible expiry countdown')
replace(TRAFFIC,
    '''class _TrendPanel extends StatelessWidget {
  const _TrendPanel({required this.series, required this.periodDays,
    required this.usagePoints, required this.onPeriodChanged});
  final TrafficHistorySeries series;
  final int periodDays;
  final List<TrafficUsagePoint> usagePoints;
  final ValueChanged<int> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(18),''',
    '''class _TrendPanel extends StatefulWidget {
  const _TrendPanel({required this.series, required this.periodDays,
    required this.usagePoints, required this.onPeriodChanged});
  final TrafficHistorySeries series;
  final int periodDays;
  final List<TrafficUsagePoint> usagePoints;
  final ValueChanged<int> onPeriodChanged;

  @override
  State<_TrendPanel> createState() => _TrendPanelState();
}

class _TrendPanelState extends State<_TrendPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _scrollKey;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;
    final periodDays = widget.periodDays;
    final usagePoints = widget.usagePoints;
    final onPeriodChanged = widget.onPeriodChanged;
    if (series.days.isNotEmpty && series.recordedDays > 0) {
      final last = series.days.last.date;
      final key = '$periodDays:${last.year}-${last.month}-${last.day}';
      if (_scrollKey != key) {
        _scrollKey = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    }
    final p = V3Palette.of(context);
    return Container(width: double.infinity, padding: const EdgeInsets.all(18),''',
    'auto-scroll traffic trend state')
replace(TRAFFIC,
    '''return SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: SizedBox(width: width,''',
    '''return SingleChildScrollView(
                  key: const Key('v3-traffic-trend-scroll'),
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(width: width,''',
    'bind trend scroll controller')

ORDERS = 'lib/v3/pages/v3_orders_page.dart'
replace(ORDERS,
    '''    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim() : order.periodLabel;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 15),''',
    '''    final title = order.planName?.trim().isNotEmpty == true
        ? order.planName!.trim() : order.periodLabel;
    // On phones, payment must not be hidden in an overflow menu.
    if (MediaQuery.sizeOf(context).width < 520) {
      return Padding(
        key: const Key('v3-order-phone-row'),
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(title, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 14,
                fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Text(_statusLabel(context, order),
              style: TextStyle(color: statusColor, fontSize: 11,
                fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('${order.tradeNo} · ${order.dateDisplay}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 10))),
            const SizedBox(width: 8),
            Text(order.amountDisplay(currencySymbol),
              style: TextStyle(color: p.ink, fontSize: 13,
                fontWeight: FontWeight.w900)),
          ]),
          if (order.status == 0) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                key: const Key('v3-order-phone-cancel'),
                onPressed: busy ? null : onCancel,
                child: Text(v3Copy(context,
                  zh: '取消订单', en: 'Cancel order', tw: '取消訂單')))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                key: const Key('v3-order-phone-pay'),
                onPressed: busy ? null : onPay,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: Colors.white),
                child: busy
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                  : Text(v3Copy(context,
                      zh: '继续支付', en: 'Continue payment', tw: '繼續付款')))),
            ]),
          ],
        ]),
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 15),''',
    'phone order actions and two-line title')

TICKETS = 'lib/v3/pages/v3_tickets_page.dart'
replace(TICKETS,
    '''      _ => v3Copy(context, zh: ticket.levelLabel,
        en: 'Low', tw: '低'),
    };
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,''',
    '''      _ => v3Copy(context, zh: ticket.levelLabel,
        en: 'Low', tw: '低'),
    };
    if (MediaQuery.sizeOf(context).width < 520) {
      return InkWell(
        key: const Key('v3-ticket-phone-row'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14,
          horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(ticket.subject.trim().isEmpty
                  ? v3Copy(context, zh: '未命名工单',
                      en: 'Untitled ticket', tw: '未命名工單')
                  : ticket.subject,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 14,
                    fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Text(v3Copy(context, zh: ticket.statusLabel,
                    en: ticket.isOpen ? 'Open' : 'Closed',
                    tw: ticket.isOpen ? '處理中' : '已關閉'),
                  style: TextStyle(color: statusColor, fontSize: 11,
                    fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(levelLabel,
                    style: TextStyle(color: levelColor, fontSize: 10,
                      fontWeight: FontWeight.w800))),
                const SizedBox(width: 8),
                Expanded(child: Text('#${ticket.id} · ${ticket.dateDisplay}',
                  textAlign: TextAlign.end, maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 10))),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                  color: p.inkMuted, size: 17),
              ]),
            ])),
      );
    }
    return InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap,''',
    'two-line phone ticket layout')

DASH = 'lib/v3/pages/v3_dashboard_page.dart'
replace(DASH,
    "import '../ui/v3_node_picker.dart';\n",
    "import '../ui/v3_node_picker.dart';\nimport '../ui/v3_toast.dart';\n",
    'dashboard toast import')
replace(DASH,
    '''                  : () async {
                      // Persistent alert and retry are driven by core state.
                      await controller.toggleConnection();
                    },''',
    '''                  : () async {
                      // Only a successful start gets a toast; failures stay in
                      // the persistent red connection alert with a retry.
                      final overlay = Overlay.of(context, rootOverlay: true);
                      final wasConnected = connected;
                      final error = await controller.toggleConnection();
                      if (context.mounted && overlay.mounted && !wasConnected &&
                          (error == null || error.isEmpty) &&
                          controller.connectionStatus == ConnectionStatus.connected) {
                        V3Toast.showInOverlay(overlay,
                          v3Copy(context, zh: '连接成功',
                            en: 'Connected successfully', tw: '連線成功'),
                          type: V3ToastType.success);
                      }
                    },''',
    'successful connection feedback')
replace(DASH,
    '''        onPressed: () async {
          final error = await controller.setProxyMode(mode);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          }
        },''',
    '''        onPressed: () async {
          if (active) return;
          final error = await controller.setProxyMode(mode);
          if (!context.mounted) return;
          if (error != null) {
            V3Toast.show(context, error, type: V3ToastType.error);
          } else {
            V3Toast.show(context,
              v3Copy(context, zh: '路由模式切换成功',
                en: 'Routing mode changed', tw: '路由模式切換成功'),
              type: V3ToastType.success);
          }
        },''',
    'successful routing feedback')

# One-time runner files are intentionally deleted by the workflow after tests.

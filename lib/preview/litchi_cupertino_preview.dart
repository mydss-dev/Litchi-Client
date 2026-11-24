// Litchi Cupertino full-suite visual preview.
// Run: flutter run -t lib/preview/litchi_cupertino_preview.dart -d emulator-5554
//
// UI only: local demo data, no authentication, payment, network or proxy core.
// Production application entrypoint lib/main.dart is unaffected.
import 'package:flutter/cupertino.dart';

void main() => runApp(const LitchiCupertinoPreview());

abstract final class _T {
  static const bg = Color(0xFFF2F2F7);
  static const card = Color(0xFFFFFFFF);
  static const raised = Color(0xFFF7F7FA);
  static const ink = Color(0xFF1C1C1E);
  static const muted = Color(0xFF85858B);
  static const line = Color(0xFFE8E8ED);
  static const coral = Color(0xFFF25E48);
  static const coralSoft = Color(0xFFFFEAE6);
  static const green = Color(0xFF16885D);
  static const greenSoft = Color(0xFFE7F5ED);
  static const orange = Color(0xFFAB6C27);
}

class LitchiCupertinoPreview extends StatelessWidget {
  const LitchiCupertinoPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Litchi · Cupertino UI Preview',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: _T.coral,
        scaffoldBackgroundColor: _T.bg,
        barBackgroundColor: _T.card,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            fontSize: 14,
            color: _T.ink,
          ),
        ),
      ),
      home: _PreviewHome(),
    );
  }
}

class _PreviewHome extends StatefulWidget {
  const _PreviewHome();

  @override
  State<_PreviewHome> createState() => _PreviewHomeState();
}

class _PreviewHomeState extends State<_PreviewHome> {
  int tab = 0;
  bool connected = false;
  String selectedNode = '美国 · 洛杉矶 01';
  String mode = '规则';

  void open(Widget child) {
    Navigator.of(context).push(CupertinoPageRoute<void>(
      builder: (_) => child,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _ConnectScreen(
        connected: connected,
        node: selectedNode,
        mode: mode,
        onToggle: () => setState(() => connected = !connected),
        onMode: (v) => setState(() => mode = v),
        onNodes: () => setState(() => tab = 1),
        onNotice: () => _showNotice(context),
      ),
      _NodesScreen(
        selected: selectedNode,
        onSelect: (value) => setState(() {
          selectedNode = value;
          tab = 0;
        }),
      ),
      _PlansScreen(onOrders: () => open(const _OrdersPage())),
      _AccountScreen(onOpen: open),
    ];

    return CupertinoPageScaffold(
      backgroundColor: _T.bg,
      child: Column(children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: IndexedStack(index: tab, children: screens),
          ),
        ),
        CupertinoTabBar(
          currentIndex: tab,
          onTap: (value) => setState(() => tab = value),
          activeColor: _T.coral,
          inactiveColor: _T.muted,
          backgroundColor: const Color(0xECFFFFFF),
          border: const Border(top: BorderSide(
            color: _T.line, width: .6)),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.home), label: '连接'),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.globe), label: '节点'),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.bag), label: '套餐'),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.person), label: '我的'),
          ],
        ),
      ]),
    );
  }
}

Widget _header(String title, {String? subtitle, Widget? trailing}) => Padding(
  padding: const EdgeInsets.fromLTRB(1, 4, 1, 21),
  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          color: _T.ink, fontSize: 31,
          fontWeight: FontWeight.w700, letterSpacing: -.8)),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle, style: const TextStyle(
            color: _T.muted, fontSize: 12)),
        ],
      ],
    )),
    ?trailing,
  ]),
);

Widget _caption(String label) => Padding(
  padding: const EdgeInsets.fromLTRB(3, 6, 0, 9),
  child: Text(label, style: const TextStyle(
    color: _T.muted, fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: .5)),
);

Widget _panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(17)}) =>
    Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _T.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.line, width: .7),
      ),
      child: child,
    );

Widget _divider() => const Container(height: .7, color: _T.line);

Widget _hint(String text) => Text(text, style: const TextStyle(
  color: _T.muted, fontSize: 12, height: 1.4));

Widget _primaryButton(String label, VoidCallback action) =>
    SizedBox(width: double.infinity, child: CupertinoButton.filled(
      onPressed: action,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(label, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600)),
    ));

Widget _pill(String text, {bool green = false}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: green ? _T.greenSoft : _T.coralSoft,
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(text, style: TextStyle(
    color: green ? _T.green : _T.coral,
    fontSize: 11, fontWeight: FontWeight.w700,
  )),
);

class _ConnectScreen extends StatelessWidget {
  const _ConnectScreen({
    required this.connected,
    required this.node,
    required this.mode,
    required this.onToggle,
    required this.onMode,
    required this.onNodes,
    required this.onNotice,
  });
  final bool connected;
  final String node;
  final String mode;
  final VoidCallback onToggle;
  final ValueChanged<String> onMode;
  final VoidCallback onNodes;
  final VoidCallback onNotice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      children: [
        _header('Litchi', subtitle: '连接，自然且安全',
          trailing: CupertinoButton(
            padding: EdgeInsets.zero, onPressed: onNotice,
            child: const Icon(CupertinoIcons.bell, size: 22),
          )),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onNotice,
          child: _panel(Row(children: [
            Container(
              width: 37, height: 37,
              decoration: BoxDecoration(
                color: _T.coralSoft,
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.bell,
                color: _T.coral, size: 19)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('防失联通知', style: TextStyle(
                  color: _T.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 3),
                Text('查看最新公告与服务消息',
                  style: TextStyle(color: _T.muted, fontSize: 11)),
              ],
            )),
            const Icon(CupertinoIcons.chevron_right,
              size: 15, color: _T.muted),
          ]), padding: const EdgeInsets.all(13)),
        ),
        const SizedBox(height: 38),
        Center(child: _pill(
          connected ? '●  已保护连接' : '○  尚未连接',
          green: connected)),
        const SizedBox(height: 21),
        Center(
          child: CupertinoButton(
            onPressed: onToggle,
            padding: EdgeInsets.zero,
            child: Container(
              width: 126, height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: connected ? _T.green : _T.coral,
                boxShadow: [
                  BoxShadow(
                    color: (connected ? _T.green : _T.coral)
                        .withValues(alpha: .15),
                    blurRadius: 28, spreadRadius: 3),
                ],
              ),
              child: const Icon(CupertinoIcons.power,
                color: CupertinoColors.white, size: 43),
            ),
          ),
        ),
        const SizedBox(height: 17),
        Center(child: Text(connected ? '已连接' : '点击连接',
          style: const TextStyle(color: _T.ink,
            fontSize: 25, fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        Center(child: _hint(
          connected ? '00:18:42  ·  连接已加密' : '一键开启安全连接')),
        const SizedBox(height: 21),
        Center(child: Text('↑ 3.4 MB/s    ↓ 11.4 MB/s',
          style: TextStyle(color: connected ? _T.green : _T.muted,
            fontSize: 12, fontWeight: FontWeight.w600))),
        const SizedBox(height: 43),
        _caption('当前节点'),
        _panel(CupertinoButton(
          onPressed: onNodes,
          padding: EdgeInsets.zero,
          child: Row(children: [
            Container(
              width: 43, height: 43, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _T.raised, borderRadius: BorderRadius.circular(12)),
              child: const Text('🇺🇸', style: TextStyle(fontSize: 26))),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node, style: const TextStyle(
                  color: _T.ink, fontSize: 14,
                  fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('42 ms · 自动选择',
                  style: TextStyle(color: _T.muted, fontSize: 11)),
              ],
            )),
            const Icon(CupertinoIcons.chevron_right,
              color: _T.muted, size: 16),
          ]),
        ), padding: const EdgeInsets.all(13)),
        const SizedBox(height: 14),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: mode,
          children: const {
            '规则': Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('规则')),
            '全局': Text('全局'),
            '直连': Text('直连'),
          },
          onValueChanged: (value) {
            if (value != null) onMode(value);
          },
        ),
      ],
    );
  }
}

class _NodesScreen extends StatefulWidget {
  const _NodesScreen({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<_NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<_NodesScreen> {
  String query = '';
  int region = 0;
  static const nodes = <(String, String, int, String)>[
    ('美国 · 洛杉矶 01', '🇺🇸', 42, 'United States'),
    ('美国 · 洛杉矶 02', '🇺🇸', 68, 'United States'),
    ('日本 · 东京', '🇯🇵', 51, 'Asia'),
    ('新加坡 · Premium', '🇸🇬', 36, 'Asia'),
    ('香港 · Premium', '🇭🇰', 28, 'Asia'),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = nodes.where((n) =>
      n.$1.toLowerCase().contains(query.toLowerCase()) &&
      (region == 0 || (region == 1 ? n.$4 == 'United States' : n.$4 == 'Asia'))
    ).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      children: [
        _header('节点', subtitle: '选择适合你的网络线路'),
        CupertinoSearchTextField(
          placeholder: '搜索节点或地区',
          onChanged: (v) => setState(() => query = v),
        ),
        const SizedBox(height: 18),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: region,
          children: const {
            0: Text('全部'),
            1: Text('美国'),
            2: Text('亚洲'),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => region = v);
          },
        ),
        const SizedBox(height: 22),
        _caption('可用节点  ·  ' + filtered.length.toString()),
        _panel(Column(children: [
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) _divider(),
            CupertinoListTile(
              padding: const EdgeInsets.symmetric(vertical: 8),
              leading: Text(filtered[i].$2,
                style: const TextStyle(fontSize: 25)),
              title: Text(filtered[i].$1, style: const TextStyle(
                color: _T.ink, fontSize: 13,
                fontWeight: FontWeight.w600)),
              subtitle: Text(filtered[i].$4,
                style: const TextStyle(fontSize: 11)),
              additionalInfo: Text(
                filtered[i].$3.toString() + ' ms',
                style: TextStyle(
                  color: filtered[i].$3 < 60 ? _T.green : _T.orange,
                  fontSize: 12, fontWeight: FontWeight.w600)),
              trailing: Icon(
                filtered[i].$1 == widget.selected
                    ? CupertinoIcons.check_mark
                    : CupertinoIcons.chevron_right,
                color: filtered[i].$1 == widget.selected
                    ? _T.coral : _T.muted, size: 17),
              onTap: () => widget.onSelect(filtered[i].$1),
            ),
          ],
          if (filtered.isEmpty)
            Padding(padding: const EdgeInsets.all(24),
              child: Center(child: _hint('没有找到符合条件的节点'))),
        ]), padding: const EdgeInsets.symmetric(horizontal: 13)),
        const SizedBox(height: 13),
        _hint('预览中的延迟、地区与节点均为演示数据。'),
      ],
    );
  }
}

class _PlansScreen extends StatefulWidget {
  const _PlansScreen({required this.onOrders});
  final VoidCallback onOrders;

  @override
  State<_PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<_PlansScreen> {
  int filter = 0;

  @override
  Widget build(BuildContext context) {
    final plans = <(String, String, String, String, bool)>[
      ('Litchi Elite', '128 GB', '¥12.80', '月付 · 最多 2 台设备', true),
      ('Litchi Ultra', '256 GB', '¥22.80', '月付 · 最多 5 台设备', true),
      ('额外流量包', '300 GB', '¥18.00', '一次性购买 · 不限设备', false),
    ];
    final shown = plans.where((p) =>
      filter == 0 || (filter == 1 ? p.$5 : !p.$5)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
      children: [
        _header('套餐', subtitle: '简单透明，按需选择'),
        _panel(Row(children: [
          Container(
            width: 37, height: 37,
            decoration: BoxDecoration(
              color: _T.greenSoft,
              borderRadius: BorderRadius.circular(11)),
            child: const Icon(CupertinoIcons.check_mark,
              color: _T.green, size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前套餐 · Ultra', style: TextStyle(
                color: _T.ink, fontSize: 14,
                fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('128 GB 剩余 · 2027-12-31 到期',
                style: TextStyle(color: _T.muted, fontSize: 11)),
            ],
          )),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: widget.onOrders,
            child: const Icon(CupertinoIcons.chevron_right,
              color: _T.muted, size: 16)),
        ]), padding: const EdgeInsets.all(13)),
        const SizedBox(height: 18),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: filter,
          children: const {
            0: Text('全部'),
            1: Text('周期套餐'),
            2: Text('流量包'),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => filter = v);
          },
        ),
        const SizedBox(height: 17),
        for (final p in shown) ...[
          _panel(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(p.$1, style: const TextStyle(
                  color: _T.ink, fontSize: 17,
                  fontWeight: FontWeight.w700))),
                if (p.$1 == 'Litchi Ultra')
                  _pill('推荐', green: true),
              ]),
              const SizedBox(height: 8),
              Text(p.$4, style: const TextStyle(
                color: _T.muted, fontSize: 12)),
              const SizedBox(height: 21),
              Text(p.$2, style: const TextStyle(
                color: _T.ink, fontSize: 26,
                fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              _hint('包含高速节点 · 灵活切换'),
              const SizedBox(height: 19),
              Row(children: [
                Text(p.$3, style: const TextStyle(
                  color: _T.ink, fontSize: 21,
                  fontWeight: FontWeight.w700)),
                const Spacer(),
                SizedBox(width: 106, child: CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => _message(context, '演示模式',
                    '套餐购买未连接真实支付服务。'),
                  child: const Text('选择套餐',
                    style: TextStyle(fontSize: 12)),
                )),
              ]),
            ],
          )),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _AccountScreen extends StatelessWidget {
  const _AccountScreen({required this.onOpen});
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _header('我的', subtitle: '账户与会员'),
        _panel(Column(children: [
          Row(children: [
            Container(
              width: 47, height: 47,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _T.coralSoft, shape: BoxShape.circle),
              child: const Text('L', style: TextStyle(
                color: _T.coral, fontSize: 19,
                fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Litchi User', style: TextStyle(
                  color: _T.ink, fontSize: 16,
                  fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('会员 · Ultra 256 GB',
                  style: TextStyle(color: _T.muted, fontSize: 11)),
              ],
            )),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onOpen(const _ManagePage()),
              child: const Icon(CupertinoIcons.chevron_right,
                color: _T.muted, size: 18)),
          ]),
          const SizedBox(height: 18),
          _divider(),
          const SizedBox(height: 16),
          const Row(children: [
            Expanded(child: _AccountStat(
              label: '到期日期', value: '2027.12.31')),
            Expanded(child: _AccountStat(
              label: '剩余有效期', value: '401 天', green: true)),
          ]),
        ])),
        const SizedBox(height: 13),
        _panel(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('我的钱包', style: TextStyle(
              color: _T.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: _AccountStat(
                label: '账户余额', value: '¥128.00')),
              Expanded(child: _AccountStat(
                label: '可提现', value: '¥35.50')),
              Expanded(child: _AccountStat(
                label: '累计佣金', value: '¥53.00')),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _MiniAction(
                title: '充值', icon: CupertinoIcons.add,
                primary: true,
                onTap: () => _message(context, '演示模式',
                  '充值入口暂未连接支付服务。'))),
              const SizedBox(width: 8),
              Expanded(child: _MiniAction(
                title: '提现', icon: CupertinoIcons.arrow_down,
                onTap: () => _message(context, '演示模式',
                  '提现入口暂未连接账户服务。'))),
              const SizedBox(width: 8),
              Expanded(child: _MiniAction(
                title: '划转', icon: CupertinoIcons.arrow_2_squarepath,
                onTap: () => _message(context, '演示模式',
                  '划转入口暂未连接账户服务。'))),
            ]),
          ],
        )),
        const SizedBox(height: 22),
        _caption('账户服务'),
        _panel(Column(children: [
          _ServiceRow('订单记录', '查询订单与支付明细',
            CupertinoIcons.doc_text, () => onOpen(const _OrdersPage())),
          _divider(),
          _ServiceRow('流量用量', '剩余 128 GB',
            CupertinoIcons.chart_bar, () => onOpen(const _UsagePage())),
          _divider(),
          _ServiceRow('帮助与工单', '咨询与售后',
            CupertinoIcons.chat_bubble, () => onOpen(const _TicketsPage())),
          _divider(),
          _ServiceRow('邀请好友', '邀请码与佣金',
            CupertinoIcons.person_2, () => onOpen(const _InvitePage())),
          _divider(),
          _ServiceRow('应用设置', '语言 · 外观 · 网络',
            CupertinoIcons.settings, () => onOpen(const _SettingsPage())),
        ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
        const SizedBox(height: 15),
        _hint('Cupertino 整套 UI 演示 · 所有金额和套餐均为示例数据。'),
      ],
    );
  }
}

class _AccountStat extends StatelessWidget {
  const _AccountStat({
    required this.label, required this.value, this.green = false});
  final String label;
  final String value;
  final bool green;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
        color: _T.muted, fontSize: 11)),
      const SizedBox(height: 7),
      FittedBox(fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, style: TextStyle(
          color: green ? _T.green : _T.ink,
          fontSize: 16, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.title, required this.icon,
    required this.onTap, this.primary = false});
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      color: primary ? _T.coral : _T.raised,
      borderRadius: BorderRadius.circular(12),
      onPressed: onTap,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16,
          color: primary ? _T.card : _T.ink),
        const SizedBox(width: 5),
        Text(title, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: primary ? _T.card : _T.ink)),
      ]),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow(this.title, this.subtitle, this.icon, this.onTap);
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(vertical: 8),
      leading: Icon(icon, color: _T.muted, size: 20),
      title: Text(title, style: const TextStyle(
        color: _T.ink, fontSize: 14,
        fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(
        color: _T.muted, fontSize: 11)),
      trailing: const Icon(CupertinoIcons.chevron_right,
        color: _T.muted, size: 16),
      onTap: onTap,
    );
  }
}

class _Secondary extends StatelessWidget {
  const _Secondary({
    required this.title,
    required this.children,
    this.backTitle = '我的',
  });
  final String title;
  final List<Widget> children;
  final String backTitle;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: _T.bg,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        previousPageTitle: backTitle,
        backgroundColor: const Color(0xF5FFFFFF),
        border: const Border(bottom: BorderSide(
          color: _T.line, width: .5)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: children,
        ),
      ),
    );
  }
}

class _OrderDemo {
  const _OrderDemo(this.name, this.id, this.amount,
      this.date, this.status);
  final String name;
  final String id;
  final String amount;
  final String date;
  final String status;
}

class _OrdersPage extends StatefulWidget {
  const _OrdersPage();

  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  int filter = 0;
  static const orders = <_OrderDemo>[
    _OrderDemo('Litchi Ultra · 256 GB',
      'L202611240001', '¥22.80', '2026-11-24', '待支付'),
    _OrderDemo('Litchi Elite · 128 GB',
      'L202611100035', '¥12.80', '2026-11-10', '已完成'),
    _OrderDemo('额外流量包 · 300 GB',
      'L202610150012', '¥18.00', '2026-10-15', '已完成'),
    _OrderDemo('Litchi Ultra · 256 GB',
      'L202609120018', '¥22.80', '2026-09-12', '已取消'),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = orders.where((o) => filter == 0 ||
      (filter == 1 && o.status == '待支付') ||
      (filter == 2 && o.status == '已完成') ||
      (filter == 3 && o.status == '已取消')).toList();
    return _Secondary(
      title: '订单记录',
      children: [
        _hint('所有订单均可点击查看完整详情'),
        const SizedBox(height: 15),
        CupertinoSlidingSegmentedControl<int>(
          groupValue: filter,
          children: const {
            0: Text('全部'),
            1: Text('待支付'),
            2: Text('已完成'),
            3: Text('已取消'),
          },
          onValueChanged: (v) {
            if (v != null) setState(() => filter = v);
          },
        ),
        const SizedBox(height: 23),
        _caption('订单列表  ·  ' + shown.length.toString() + ' 笔'),
        _panel(Column(children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) _divider(),
            CupertinoListTile(
              padding: const EdgeInsets.symmetric(vertical: 10),
              title: Text(shown[i].name,
                style: const TextStyle(color: _T.ink,
                  fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(shown[i].id + '  ·  ' + shown[i].date,
                  style: const TextStyle(color: _T.muted, fontSize: 10)),
              ),
              additionalInfo: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(shown[i].amount, style: const TextStyle(
                    color: _T.ink, fontSize: 14,
                    fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(shown[i].status, style: TextStyle(
                    color: shown[i].status == '已完成'
                        ? _T.green : _T.muted,
                    fontSize: 10)),
                ],
              ),
              trailing: const Icon(CupertinoIcons.chevron_right,
                size: 14, color: _T.muted),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => _OrderDetail(order: shown[i]))),
            ),
          ],
          if (shown.isEmpty)
            Padding(padding: const EdgeInsets.all(22),
              child: Center(child: _hint('当前筛选下暂无订单'))),
        ]), padding: const EdgeInsets.symmetric(horizontal: 12)),
      ],
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.order});
  final _OrderDemo order;

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '订单详情', backTitle: '订单记录', children: [
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _pill(order.status, green: order.status == '已完成'),
        const SizedBox(height: 12),
        Text(order.amount, style: const TextStyle(
          color: _T.ink, fontSize: 31,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        _hint(order.name),
      ])),
      const SizedBox(height: 20),
      _caption('订单信息'),
      _panel(Column(children: [
        _DetailRow('订单编号', order.id),
        _divider(),
        _DetailRow('套餐名称', order.name),
        _divider(),
        _DetailRow('订单金额', order.amount),
        _divider(),
        _DetailRow('创建日期', order.date),
        _divider(),
        _DetailRow('订单状态', order.status),
      ])),
      const SizedBox(height: 19),
      _caption('支付明细'),
      _panel(const Column(children: [
        _DetailRow('商品金额', '¥22.80'),
        _dividerFixed(),
        _DetailRow('优惠金额', '¥0.00'),
        _dividerFixed(),
        _DetailRow('余额抵扣', '¥0.00'),
      ])),
      if (order.status == '待支付') ...[
        const SizedBox(height: 23),
        _primaryButton('继续支付', () => _message(context,
          '演示模式', '这里会调用真实订单的支付流程。')),
      ],
    ]);
  }
}

class _dividerFixed extends StatelessWidget {
  const _dividerFixed();

  @override
  Widget build(BuildContext context) => _divider();
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(children: [
      SizedBox(width: 83,
        child: Text(label, style: const TextStyle(
          color: _T.muted, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: Text(value,
        textAlign: TextAlign.right,
        style: const TextStyle(color: _T.ink, fontSize: 12,
          fontWeight: FontWeight.w600))),
    ]),
  );
}

class _UsagePage extends StatelessWidget {
  const _UsagePage();

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '流量用量', children: [
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _hint('本月剩余流量'),
        const SizedBox(height: 8),
        const Text('128.0 GB', style: TextStyle(
          color: _T.ink, fontSize: 32,
          fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        ClipRRect(borderRadius: BorderRadius.circular(12),
          child: const LinearProgressIndicatorPreview(value: .5)),
        const SizedBox(height: 11),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('已用 128 GB', style: TextStyle(
              color: _T.muted, fontSize: 11)),
            Text('总量 256 GB', style: TextStyle(
              color: _T.muted, fontSize: 11)),
          ]),
      ])),
      const SizedBox(height: 13),
      _panel(const Row(children: [
        Expanded(child: _AccountStat(
          label: '今日使用', value: '0.80 GB')),
        Expanded(child: _AccountStat(
          label: '在线设备', value: '1 / 2')),
      ])),
      const SizedBox(height: 19),
      _caption('最近 7 天'),
      _panel(Column(children: [
        _hint('每日流量使用示意'),
        const SizedBox(height: 24),
        const SizedBox(
          height: 128,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _UsageBar(.25, '一'),
              _UsageBar(.48, '二'),
              _UsageBar(.35, '三'),
              _UsageBar(.67, '四'),
              _UsageBar(.58, '五'),
              _UsageBar(.90, '六'),
              _UsageBar(.42, '日'),
            ]),
        ),
      ])),
    ]);
  }
}

// A simple display-only bar, not a second charting/UI framework.
class _UsageBar extends StatelessWidget {
  const _UsageBar(this.ratio, this.label);
  final double ratio;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
        width: 21,
        height: 96 * ratio,
        decoration: BoxDecoration(
          color: _T.green.withValues(alpha: .9),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(5)),
        ),
      ),
      const SizedBox(height: 7),
      Text(label, style: const TextStyle(
        color: _T.muted, fontSize: 10)),
    ]);
  }
}

class LinearProgressIndicatorPreview extends StatelessWidget {
  const LinearProgressIndicatorPreview({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => Container(
    height: 7,
    decoration: BoxDecoration(
      color: _T.line, borderRadius: BorderRadius.circular(8)),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value,
      child: Container(decoration: BoxDecoration(
        color: _T.green, borderRadius: BorderRadius.circular(8))),
    ),
  );
}

class _TicketsPage extends StatelessWidget {
  const _TicketsPage();

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '帮助与工单', children: [
      _primaryButton('＋  新建工单', () => _message(context,
        '演示模式', '新建工单功能将接入现有服务。')),
      const SizedBox(height: 24),
      _caption('工单列表'),
      _panel(Column(children: [
        _ServiceRow('连接失败怎么办？', '已解决 · 2026-11-16',
          CupertinoIcons.chat_bubble,
          () => _message(context, '工单详情',
            '已解决：可尝试切换节点并重新连接。')),
        _divider(),
        _ServiceRow('套餐续费咨询', '处理中 · 2026-11-21',
          CupertinoIcons.chat_bubble,
          () => _message(context, '工单详情',
            '客服正在处理该咨询。')),
      ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
      const SizedBox(height: 17),
      _hint('点击任意工单可查看详情（演示内容）。'),
    ]);
  }
}

class _InvitePage extends StatelessWidget {
  const _InvitePage();

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '邀请好友', children: [
      _panel(Column(children: [
        _hint('我的邀请码'),
        const SizedBox(height: 12),
        const Text('LITCHI26', style: TextStyle(
          color: _T.ink, fontSize: 29,
          fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 14),
        _primaryButton('复制邀请码', () => _message(context,
          '演示邀请码', '正式版将复制你的真实邀请码。')),
      ])),
      const SizedBox(height: 12),
      _panel(const Row(children: [
        Expanded(child: _AccountStat(label: '邀请人数', value: '6')),
        Expanded(child: _AccountStat(label: '累计佣金', value: '¥53.00')),
      ])),
      const SizedBox(height: 21),
      _caption('分享邀请'),
      _panel(Column(children: [
        _ServiceRow('复制邀请链接', '分享给好友',
          CupertinoIcons.link,
          () => _message(context, '演示模式', '正式版将复制真实邀请链接。')),
        _divider(),
        _ServiceRow('邀请奖励说明', '了解返佣与活动规则',
          CupertinoIcons.info, () => _message(context,
            '邀请奖励', '具体规则以服务端配置为准。')),
      ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
    ]);
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  bool update = true;
  bool alerts = true;
  bool haptics = true;

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '应用设置', children: [
      _caption('通用'),
      _panel(Column(children: [
        _SettingToggle('自动检查更新', update,
          (v) => setState(() => update = v)),
        _divider(),
        _SettingToggle('消息提醒', alerts,
          (v) => setState(() => alerts = v)),
        _divider(),
        _SettingToggle('触觉反馈', haptics,
          (v) => setState(() => haptics = v)),
      ])),
      const SizedBox(height: 20),
      _caption('外观与语言'),
      _panel(Column(children: [
        _ServiceRow('主题外观', '跟随系统（演示）',
          CupertinoIcons.paintbrush, () =>
            _message(context, '主题外观', '正式版支持跟随系统、浅色、深色。')),
        _divider(),
        _ServiceRow('界面语言', '简体中文',
          CupertinoIcons.globe, () =>
            _message(context, '语言设置', '正式版沿用已有多语言配置。')),
      ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
      const SizedBox(height: 20),
      _caption('体验整套页面'),
      _panel(Column(children: [
        _ServiceRow('登录页面', '查看统一登录样式',
          CupertinoIcons.lock, () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const _LoginPreview()))),
        _divider(),
        _ServiceRow('公告弹窗', '查看系统通知样式',
          CupertinoIcons.bell, () => _showNotice(context)),
        _divider(),
        _ServiceRow('关于 Litchi', '版本信息（演示）',
          CupertinoIcons.info, () => _message(context,
            '关于 Litchi', 'Cupertino UI 设计预览，不代表正式版本。')),
      ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
    ]);
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle(this.label, this.value, this.onChange);
  final String label;
  final bool value;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(children: [
      Expanded(child: Text(label,
        style: const TextStyle(color: _T.ink, fontSize: 14))),
      CupertinoSwitch(value: value, onChanged: onChange),
    ]),
  );
}

class _ManagePage extends StatefulWidget {
  const _ManagePage();

  @override
  State<_ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<_ManagePage> {
  bool expiry = true;
  bool traffic = true;
  bool renewal = false;

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '管理账户', children: [
      _caption('通知偏好'),
      _panel(Column(children: [
        _SettingToggle('到期提醒', expiry,
          (v) => setState(() => expiry = v)),
        _divider(),
        _SettingToggle('流量提醒', traffic,
          (v) => setState(() => traffic = v)),
        _divider(),
        _SettingToggle('自动续费', renewal,
          (v) => setState(() => renewal = v)),
      ])),
      const SizedBox(height: 20),
      _caption('账户安全'),
      _panel(Column(children: [
        _ServiceRow('修改密码', '保护账户安全',
          CupertinoIcons.lock, () => _message(context,
            '演示模式', '正式版将调用已有修改密码功能。')),
        _divider(),
        _ServiceRow('Telegram 通知', '消息与服务提醒',
          CupertinoIcons.paperplane, () => _message(context,
            '演示模式', '正式版将调用已有绑定功能。')),
        _divider(),
        _ServiceRow('退出登录', '返回登录页面',
          CupertinoIcons.person, () => Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (_) => const _LoginPreview()))),
      ]), padding: const EdgeInsets.symmetric(horizontal: 14)),
    ]);
  }
}

class _LoginPreview extends StatefulWidget {
  const _LoginPreview();

  @override
  State<_LoginPreview> createState() => _LoginPreviewState();
}

class _LoginPreviewState extends State<_LoginPreview> {
  bool showPassword = false;

  @override
  Widget build(BuildContext context) {
    return _Secondary(title: '登录预览', children: [
      const SizedBox(height: 48),
      Center(child: Container(
        width: 62, height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _T.coral, borderRadius: BorderRadius.circular(20)),
        child: const Text('L', style: TextStyle(
          color: _T.card, fontSize: 31, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 25),
      const Center(child: Text('欢迎回来', style: TextStyle(
        color: _T.ink, fontSize: 27, fontWeight: FontWeight.w700))),
      const SizedBox(height: 7),
      Center(child: _hint('登录 Litchi，继续你的连接体验')),
      const SizedBox(height: 38),
      const CupertinoTextField(
        padding: EdgeInsets.all(16),
        placeholder: '邮箱地址',
        keyboardType: TextInputType.emailAddress,
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
      const SizedBox(height: 12),
      CupertinoTextField(
        padding: const EdgeInsets.all(16),
        placeholder: '密码',
        obscureText: !showPassword,
        suffix: CupertinoButton(
          padding: const EdgeInsets.only(right: 12),
          onPressed: () => setState(() => showPassword = !showPassword),
          child: Text(showPassword ? '隐藏' : '显示',
            style: const TextStyle(fontSize: 12)),
        ),
        decoration: BoxDecoration(
          color: _T.card,
          borderRadius: BorderRadius.circular(14)),
      ),
      const SizedBox(height: 20),
      _primaryButton('登录', () => _message(context,
        '仅供预览', '此页面不处理账号密码，也不会连接服务器。')),
      const SizedBox(height: 15),
      Center(child: CupertinoButton(
        onPressed: () => _message(context, '演示模式',
          '这里是密码找回入口的视觉预览。'),
        child: const Text('忘记密码？', style: TextStyle(fontSize: 13)))),
    ]);
  }
}

void _showNotice(BuildContext context) => _message(
  context,
  '防失联通知',
  '为方便接收服务公告、维护信息与重要消息，'
  '请关注官方通知渠道。\n\n这是 Cupertino 公告弹窗的交互预览。',
);

void _message(BuildContext context, String title, String detail) {
  showCupertinoDialog<void>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(detail)),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

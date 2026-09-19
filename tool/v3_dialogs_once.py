"""Apply the fourth-round visual edits atomically; deleted after CI succeeds."""
from pathlib import Path


def swap(src: str, old: str, new: str, count: int = 1) -> str:
    matches = src.count(old)
    if matches != count:
        raise RuntimeError(f'Expected {count} matches, got {matches}: {old[:100]!r}')
    return src.replace(old, new)


def in_section(src: str, begin: str, end: str, transform):
    if src.count(begin) != 1 or src.count(end) != 1:
        raise RuntimeError(f'Non-unique section boundaries: {begin} / {end}')
    start = src.index(begin)
    stop = src.index(end, start)
    return src[:start] + transform(src[start:stop]) + src[stop:]


names = {
    'sheet': Path('lib/v3/ui/v3_sheet.dart'),
    'payment': Path('lib/v3/commerce/v3_payment_flow.dart'),
    'wallet': Path('lib/v3/pages/v3_wallet_actions.dart'),
    'orders': Path('lib/v3/pages/v3_orders_page.dart'),
    'gift': Path('lib/v3/pages/v3_gift_card_page.dart'),
    'shop': Path('lib/v3/pages/v3_shop_page.dart'),
}
original = {name: path.read_text(encoding='utf-8') for name, path in names.items()}
output = {}

sheet = original['sheet']
sheet = swap(sheet, "import 'v3_components.dart';", "import 'v3_components.dart';\nimport 'v3_layout.dart';")
sheet = swap(sheet, 'padding: EdgeInsets.fromLTRB(22, 2, 22 + 0.0,\n          22 + MediaQuery.paddingOf(ctx).bottom),',
    'padding: EdgeInsets.fromLTRB(18, 4, 18,\n          18 + MediaQuery.paddingOf(ctx).bottom),')
sheet = swap(sheet, 'Radius.circular(26)', 'Radius.circular(V3Layout.cardRadius)')
sheet = swap(sheet, '      builder: content);',
    '      builder: (ctx) => Padding(\n        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),\n        child: content(ctx)));')
sheet = swap(sheet, 'insetPadding: const EdgeInsets.all(20),',
    'insetPadding: const EdgeInsets.all(16),')
sheet = swap(sheet, 'child: Container(width: 560,', 'child: Container(width: 520,')
sheet = swap(sheet, 'borderRadius: BorderRadius.circular(30),',
    'borderRadius: BorderRadius.circular(V3Layout.cardRadius),')
sheet = swap(sheet, 'Padding(padding: const EdgeInsets.fromLTRB(22, 16, 10, 4),',
    'Padding(padding: const EdgeInsets.fromLTRB(18, 14, 8, 8),')
sheet = swap(sheet, 'style: TextStyle(color: p.ink, fontSize: 19,',
    'style: TextStyle(color: p.ink, fontSize: 18,')
sheet = swap(sheet, 'padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),',
    'padding: V3Layout.pageInsets,')
output['sheet'] = sheet

payment = original['payment']
payment = swap(payment, "import '../ui/v3_components.dart';", 
    "import '../ui/v3_components.dart';\nimport '../ui/v3_dialog_frame.dart';\nimport '../ui/v3_layout.dart';")
begin = '  @override\n  Widget build(BuildContext context) {'
start = payment.index(begin, payment.index('class _V3PaymentDialogState'))
stop = payment.index('  Widget _paidView(BuildContext context)', start)
payment = payment[:start] + '''  @override
  Widget build(BuildContext context) {
    return V3DialogFrame(
      width: 520,
      padding: const EdgeInsets.all(22),
      scrollable: false,
      child: _paid ? _paidView(context) : _paymentView(context),
    );
  }

''' + payment[stop:]
payment = swap(payment, 'borderRadius: BorderRadius.circular(22),',
    'borderRadius: BorderRadius.circular(V3Layout.cardRadius),')
payment = swap(payment, 'borderRadius: BorderRadius.circular(20),',
    'borderRadius: BorderRadius.circular(14),')
output['payment'] = payment

wallet = original['wallet']
wallet = swap(wallet, "import '../ui/v3_locale_copy.dart';",
    "import '../ui/v3_locale_copy.dart';\nimport '../ui/v3_components.dart';\nimport '../ui/v3_dialog_frame.dart';")

def recharge(part):
    part = swap(part, '''    return Dialog(backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(width: 420, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(26)),
        child: Column(''',
        '''    return V3DialogFrame(width: 420,
        child: Column(''')
    part = swap(part, '          ])));', '          ]));')
    part = swap(part, 'TextField(controller: _amountController, autofocus: true,\n              keyboardType:',
        'TextField(controller: _amountController, autofocus: true,\n              onChanged: (_) => setState(() {}),\n              keyboardType:')
    part = swap(part, '''                ActionChip(label: Text('$symbol${amount.toStringAsFixed(0)}'),
                  onPressed: _busy ? null : () => setState(() =>
                    _amountController.text = amount.toStringAsFixed(0))),''',
        '''                ChoiceChip(label: Text('$symbol${amount.toStringAsFixed(0)}'),
                  selected: double.tryParse(_amountController.text.trim()) == amount,
                  side: v3ChipSide(p, selected:
                    double.tryParse(_amountController.text.trim()) == amount),
                  onSelected: _busy ? null : (_) => setState(() =>
                    _amountController.text = amount.toStringAsFixed(0))),''')
    return part

wallet = in_section(wallet, 'class _RechargeDialogState extends State<_RechargeDialog>',
    'class _AmountDialog extends StatefulWidget', recharge)

def amount(part):
    part = swap(part, '''    return Dialog(backgroundColor: Colors.transparent,
      child: Container(width: 400, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(26)),
        child: Column(''',
        '''    return V3DialogFrame(width: 400,
        child: Column(''')
    return swap(part, '          ])));', '          ]));')

wallet = in_section(wallet, 'class _AmountDialogState extends State<_AmountDialog>',
    'class _WithdrawDialog extends StatefulWidget', amount)

def withdraw(part):
    part = swap(part, '''    return Dialog(backgroundColor: Colors.transparent,
      child: Container(width: 430, padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(26)),
        child: Column(''',
        '''    return V3DialogFrame(width: 430,
        child: Column(''')
    return swap(part, '          ])));', '          ]));')

wallet = in_section(wallet, 'class _WithdrawDialogState extends State<_WithdrawDialog>',
    'class _AllAmountButton extends StatelessWidget', withdraw)
wallet = swap(wallet, 'minimumSize: const Size(0, 40),',
    'minimumSize: const Size(0, 44),')
output['wallet'] = wallet

orders = original['orders']
orders = swap(orders, "import '../ui/v3_sheet.dart';",
    "import '../ui/v3_sheet.dart';\nimport '../ui/v3_dialog_frame.dart';\nimport '../ui/v3_layout.dart';")
orders = swap(orders, '''        else
          Column(children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              metrics[i],
            ],
          ]),''',
    '''        else
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
          ]),''')
orders = swap(orders, 'borderRadius: BorderRadius.circular(26),',
    'borderRadius: BorderRadius.circular(V3Layout.cardRadius),')
orders = swap(orders, '''child: SegmentedButton<int>(
                segments: [''', '''child: SegmentedButton<int>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? p.lycheeSoft : p.surfaceRaised),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                    states.contains(WidgetState.selected) ? p.lycheeInk : p.ink),
                  side: WidgetStateProperty.resolveWith((states) => BorderSide(
                    color: states.contains(WidgetState.selected) ? p.lychee : p.line)),
                ),
                segments: [''')

def metric(part):
    part = swap(part, 'return Container(height: 100, padding: const EdgeInsets.all(18),',
        'return Container(height: 72, padding: const EdgeInsets.all(12),')
    part = swap(part, '''decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(22)),''',
        '''decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line)),''')
    part = swap(part, 'Container(width: 4, height: 48,', 'Container(width: 4, height: 34,')
    part = swap(part, 'const SizedBox(width: 12),', 'const SizedBox(width: 8),')
    part = swap(part, 'fontSize: 18,', 'fontSize: 16,')
    return part

orders = in_section(orders, 'class _OrderMetric extends StatelessWidget',
    'class _OrdersSkeleton extends StatelessWidget', metric)
orders = swap(orders, '''return AlertDialog(backgroundColor: p.surface,
      title:''',
    '''return AlertDialog(backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: v3DialogShape(p),
      title:''')
output['orders'] = orders

gift = original['gift']
gift = swap(gift, 'padding: const EdgeInsets.all(22),',
    'padding: const EdgeInsets.all(18),')
gift = swap(gift, '''        V3Panel(
          child: Row(''',
    '''        V3Panel(
          padding: const EdgeInsets.all(14),
          child: Row(''')
output['gift'] = gift

shop = original['shop']
shop = swap(shop, "import '../ui/v3_layout.dart';",
    "import '../ui/v3_layout.dart';\nimport '../ui/v3_dialog_frame.dart';")
shop = swap(shop, 'shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),',
    'shape: v3DialogShape(p),')
output['shop'] = shop

assert set(output) == set(names)
for name, path in names.items():
    if output[name] == original[name]:
        raise RuntimeError(f'No change in {name}')
for name, path in names.items():
    path.write_text(output[name], encoding='utf-8')
    print(f'Updated {path}')

"""One-shot guarded visual changes; removed from the final PR after verification."""
from pathlib import Path
import re

ROOT = Path('lib/v3/pages')


def swap(source: str, old: str, new: str, count: int = 1) -> str:
    actual = source.count(old)
    if actual != count:
        raise RuntimeError(f'Expected {count} matches, found {actual}: {old[:90]!r}')
    return source.replace(old, new)


# Stage all four changes in memory: a mismatched source must never partially
# modify the working tree.
paths = {name: ROOT / f'v3_{name}_page.dart' for name in
         ('traffic', 'invite', 'tickets', 'settings')}
original = {name: path.read_text(encoding='utf-8') for name, path in paths.items()}
output = {}

traffic = original['traffic']
traffic = swap(traffic,
    'borderRadius: BorderRadius.circular(24), border: Border.all(color: p.line)),',
    'borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),')
traffic = swap(traffic, 'margin: const EdgeInsets.all(24),',
               'margin: const EdgeInsets.all(V3Layout.pageGutter),')
traffic = swap(traffic,
    'textStyle: const WidgetStatePropertyAll(TextStyle(\n'
    '                  fontSize: 11, fontWeight: FontWeight.w800))),',
    'textStyle: const WidgetStatePropertyAll(TextStyle(\n'
    '                  fontSize: 11, fontWeight: FontWeight.w800)),\n'
    '                side: WidgetStateProperty.resolveWith((states) => BorderSide(\n'
    '                  color: states.contains(WidgetState.selected)\n'
    '                    ? p.lychee : p.line)),')
traffic = swap(traffic, 'SizedBox(height: 146,', 'SizedBox(height: 156,')
start = traffic.index('class _TimingRow extends StatelessWidget')
end = traffic.index('String _dayLabel', start)
part = traffic[start:end]
part = swap(part, 'Flexible(child: Text(value, maxLines: 1,',
            'Flexible(child: Text(value, maxLines: 2,')
traffic = traffic[:start] + part + traffic[end:]
output['traffic'] = traffic

invite = original['invite']
start = invite.index('class _InviteHero extends StatelessWidget')
end = invite.index('class _InviteStats extends StatelessWidget', start)
part = invite[start:end]
part = swap(part, 'const SizedBox(height: 18),',
            'const SizedBox(height: 14),', 2)
invite = invite[:start] + part + invite[end:]
start = invite.index('class _InviteStats extends StatelessWidget')
end = invite.index('class _ReferralLedger extends StatelessWidget', start)
part = invite[start:end]
part = swap(part, 'const SizedBox(height: 15),',
            'const SizedBox(height: 12),')
part = swap(part, 'Divider(color: p.line, height: 18),',
            'Divider(color: p.line, height: 12),')
part = swap(part, 'EdgeInsets.symmetric(vertical: 8)',
            'EdgeInsets.symmetric(vertical: 6)')
part = swap(part, 'fontSize: 16,\n          fontWeight: FontWeight.w900',
            'fontSize: 15,\n          fontWeight: FontWeight.w900')
invite = invite[:start] + part + invite[end:]
start = invite.index('class _ReferralLedger extends StatelessWidget')
part = invite[start:]
part = swap(part,
    'else for (final record in records.take(8))\n          Padding(',
    'else for (final record in records.take(8))\n          Column(children: [\n            Padding(')
part = swap(part,
    '            ])),\n      ]),\n    );\n  }\n}',
    '            ])),\n            if (!identical(record, records.take(8).last))\n'
    '              Divider(color: p.line, height: 1),\n'
    '          ]),\n      ]),\n    );\n  }\n}')
part = swap(part,
    'Padding(padding: const EdgeInsets.symmetric(vertical: 10),',
    'Padding(padding: const EdgeInsets.symmetric(vertical: 8),')
invite = invite[:start] + part
output['invite'] = invite

tickets = original['tickets']
tickets = swap(tickets, 'constraints: const BoxConstraints(minHeight: 110),',
               'constraints: const BoxConstraints(minHeight: 80),')
tickets = swap(tickets,
    '          const SizedBox(height: 22),\n          Row(children: [\n'
    '            Expanded(child: _TicketMetric(',
    '          const SizedBox(height: 12),\n          V3Panel(\n'
    '            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),\n'
    '            child: Row(children: [\n'
    '            Expanded(child: _TicketMetric(')
tickets = swap(tickets,
    '          ]),\n          const SizedBox(height: 16),\n'
    '          Container(width: double.infinity, padding: const EdgeInsets.all(18),',
    '          ])),\n          const SizedBox(height: 12),\n'
    '          Container(width: double.infinity, padding: const EdgeInsets.all(18),')
start = tickets.index('class _TicketMetric extends StatelessWidget')
end = tickets.index('class _TicketsSkeleton extends StatelessWidget', start)
metric = '''class _TicketMetric extends StatelessWidget {
  const _TicketMetric({required this.label, required this.value,
    required this.accent, this.loading = false});
  final String label;
  final String value;
  final Color accent;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: SizedBox(height: 64, child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Expanded(child: Text(label, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 10))),
          ]),
          const SizedBox(height: 6),
          if (loading)
            const V3SkeletonBlock(width: 30, height: 16)
          else Text(value, style: TextStyle(color: p.ink,
            fontSize: 19, fontWeight: FontWeight.w900)),
        ],
      )),
    );
  }
}

'''
tickets = tickets[:start] + metric + tickets[end:]
output['tickets'] = tickets

settings = original['settings']
indexes = re.findall(r"index: '0[1-8]',\s*", settings)
if len(indexes) != 8:
    raise RuntimeError(f'Expected eight decorative indices, got {len(indexes)}')
settings = re.sub(r"index: '0[1-8]',\s*", '', settings)
settings = swap(settings, 'const SizedBox(height: 22),',
                'const SizedBox(height: 16),', 3)
start = settings.index('class _SettingRow extends StatelessWidget')
end = settings.index('class _Segment<T> extends StatelessWidget', start)
row = '''class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.title, required this.description,
    required this.control, this.last = false, this.fullWidthControl = false});

  final String title;
  final String description;
  final Widget control;
  final bool last;
  final bool fullWidthControl;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 600 && fullWidthControl;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
          ],
        );
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                copy, const SizedBox(height: 10), control,
              ])
            : Row(children: [
                Expanded(child: copy), const SizedBox(width: 12),
                if (fullWidthControl) SizedBox(width: 240, child: control)
                else control,
              ]);
      }),
    );
  }
}

'''
settings = settings[:start] + row + settings[end:]
start = settings.index('class _V3Switch extends StatelessWidget')
end = settings.index('class _RecoveryPanel extends StatelessWidget', start)
switch = '''class _V3Switch extends StatelessWidget {
  const _V3Switch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Semantics(
      button: true,
      toggled: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => onChanged(!value),
        child: SizedBox(width: 52, height: 44,
          child: Center(child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52, height: 30,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: value ? p.lychee : p.surfaceRaised,
              borderRadius: BorderRadius.circular(99),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 22, height: 22,
                decoration: BoxDecoration(
                  color: value ? Colors.white : p.inkMuted,
                  shape: BoxShape.circle)),
            ),
          )),
        ),
      ),
    );
  }
}

'''
settings = settings[:start] + switch + settings[end:]
output['settings'] = settings

for name, path in paths.items():
    if output[name] == original[name]:
        raise RuntimeError(f'No edit in {name}')
for name, path in paths.items():
    path.write_text(output[name], encoding='utf-8')
    print(f'Updated {path}')

"""One-shot guarded integration of PR #118 changes onto PR #120's stack.

This branch is for visual acceptance only. Do not merge it; the original PRs
remain the sources of the reviewed changes. The workflow deletes this script.
"""
from pathlib import Path
import subprocess

root = Path('lib/v3/pages')
paths = {name: root / f'v3_{name}_page.dart' for name in ('account', 'nodes', 'shop')}
original = {name: path.read_text(encoding='utf-8') for name, path in paths.items()}


def swap(text: str, before: str, after: str, count: int = 1) -> str:
    actual = text.count(before)
    if actual != count:
        raise RuntimeError(f'Expected {count} matches, got {actual}: {before[:100]!r}')
    return text.replace(before, after)


account = original['account']
account = swap(account,
    '        const SizedBox(height: 26),\n        _AccountSummaryPanel(controller: controller),\n        const SizedBox(height: 16),\n        _HubPanel(controller: controller),',
    '        const SizedBox(height: 16),\n        _AccountSummaryPanel(controller: controller),\n        const SizedBox(height: 12),\n        _HubPanel(controller: controller),')
account = swap(account,
    '            controller.withdrawable > 0) ...[\n          const SizedBox(height: 16),\n          const _WalletPanel(),\n        ],\n        const SizedBox(height: 16),',
    '            controller.withdrawable > 0) ...[\n          const SizedBox(height: 12),\n          const _WalletPanel(),\n        ],\n        const SizedBox(height: 12),')
account = swap(account,
    '          onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v)),\n        const SizedBox(height: 16),',
    '          onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v)),\n        const SizedBox(height: 12),')
start = account.index('class _AccountSummaryPanel extends StatelessWidget')
end = account.index('class _WalletPanel extends StatelessWidget', start)
part = account[start:end]
part = swap(part, 'padding: const EdgeInsets.all(22),', 'padding: const EdgeInsets.all(18),')
part = swap(part, '        const SizedBox(height: 20),\n        Divider(color: p.line, height: 1),\n        const SizedBox(height: 18),',
                 '        const SizedBox(height: 16),\n        Divider(color: p.line, height: 1),\n        const SizedBox(height: 14),')
account = account[:start] + part + account[end:]
start = account.index('class _WalletPanel extends StatelessWidget')
end = account.index('class _MoneyStat extends StatelessWidget', start)
part = account[start:end]
part = swap(part, 'padding: const EdgeInsets.all(20),', 'padding: const EdgeInsets.all(18),')
account = account[:start] + part + account[end:]
start = account.index('class _PreferencesPanel extends StatelessWidget')
part = account[start:]
part = swap(part, 'return Container(padding: const EdgeInsets.all(22),',
            'return Container(padding: const EdgeInsets.all(18),')
account = account[:start] + part

nodes = original['nodes']
nodes = swap(nodes,
    '          else\n            for (final node in nodes)\n              Padding(\n                padding: const EdgeInsets.only(bottom: 8),\n                child: _OverviewNodeRow(\n                  node: node,\n                  current:\n                      !controller.autoSelected &&\n                      controller.currentNode.id == node.id,\n                ),\n              ),',
    '          else\n            V3Panel(\n              padding: EdgeInsets.zero,\n              child: Column(children: [\n                for (var index = 0; index < nodes.length; index++) ...[\n                  if (index > 0)\n                    Divider(color: p.line, height: 1,\n                      indent: 16, endIndent: 16),\n                  _OverviewNodeRow(\n                    node: nodes[index],\n                    current: !controller.autoSelected &&\n                        controller.currentNode.id == nodes[index].id,\n                  ),\n                ],\n              ]),\n            ),')
nodes = swap(nodes,
    '    return V3Panel(\n      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),\n      child: Row(',
    "    return Padding(\n      key: ValueKey('v3-node-overview-${node.id}'),\n      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),\n      child: Row(")

shop = original['shop']
shop = swap(shop,
    '          const SizedBox(height: 18),\n          _CurrentPlanBadge(controller: controller),\n          const SizedBox(height: 14),\n          _CategoryDeck(selected: _category,',
    '          const SizedBox(height: 14),\n          _CurrentPlanBadge(controller: controller),\n          const SizedBox(height: 12),\n          _CategoryDeck(selected: _category,')
shop = swap(shop,
    '            onChanged: (value) => setState(() => _category = value)),\n          const SizedBox(height: 14),',
    '            onChanged: (value) => setState(() => _category = value)),\n          const SizedBox(height: 12),')
start = shop.index('class _CategoryDeck extends StatelessWidget')
end = shop.index('class _CurrentPlanBadge extends StatelessWidget', start)
part = shop[start:end]
part = swap(part, 'for (final item in items) Expanded(child: InkWell(\n',
            "for (final item in items) Expanded(child: InkWell(\n          key: ValueKey('v3-plan-category-${item.$1?.name ?? 'all'}'),\n")
part = swap(part, '            padding: const EdgeInsets.symmetric(vertical: 10),\n',
            '            constraints: const BoxConstraints(minHeight: 44),\n            alignment: Alignment.center,\n            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),\n')
part = swap(part, '              color: selected == item.$1 ? p.surface : Colors.transparent,',
            '              color: selected == item.$1 ? p.lycheeSoft : Colors.transparent,')
part = swap(part, '            child: Text(item.$2, textAlign: TextAlign.center,\n',
            '            child: Text(item.$2, textAlign: TextAlign.center,\n              maxLines: 1, overflow: TextOverflow.ellipsis,\n')
shop = shop[:start] + part + shop[end:]

# Pull the exact already-reviewed #118 test instead of inventing a replacement.
test_path = Path('test/visual/v3_detail_pages_unification_test.dart')
if test_path.exists():
    raise RuntimeError('The #118 test exists already; refusing to overwrite')
test_bytes = subprocess.check_output([
    'git', 'show', '53ae82905cedfcf2bf7dae740963947b67be223e:' + str(test_path)
])

# All conditions have passed. Write only after everything was checked in memory.
for name, content in [('account', account), ('nodes', nodes), ('shop', shop)]:
    paths[name].write_text(content, encoding='utf-8')
    print(f'Integrated PR #118 changes: {paths[name]}')
test_path.write_bytes(test_bytes)
print(f'Copied PR #118 regression test: {test_path}')

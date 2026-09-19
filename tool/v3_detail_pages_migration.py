from pathlib import Path

# Guard expected snippets to keep the migration independent of the other PR.
changes = {}

def modify(path, updates):
    text = Path(path).read_text(encoding='utf-8')
    for old, new in updates:
        count = text.count(old)
        if count != 1:
            raise RuntimeError(f'{path}: expected one occurrence, got {count}: {old[:90]!r}')
        text = text.replace(old, new, 1)
    changes[path] = text

nodes = 'lib/v3/pages/v3_nodes_page.dart'
modify(nodes, [
    ('''          else
            for (final node in nodes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OverviewNodeRow(
                  node: node,
                  current:
                      !controller.autoSelected &&
                      controller.currentNode.id == node.id,
                ),
              ),''', '''          else
            V3Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var index = 0; index < nodes.length; index++) ...[
                  if (index > 0)
                    Divider(color: p.line, height: 1,
                      indent: 16, endIndent: 16),
                  _OverviewNodeRow(
                    node: nodes[index],
                    current: !controller.autoSelected &&
                        controller.currentNode.id == nodes[index].id,
                  ),
                ],
              ]),
            ),'''),
    ('''    return V3Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(''', '''    return Padding(
      key: ValueKey('v3-node-overview-${node.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row('''),
])

shop = 'lib/v3/pages/v3_shop_page.dart'
modify(shop, [
    ('''        for (final item in items) Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(9),''', '''        for (final item in items) Expanded(child: InkWell(
          key: ValueKey('v3-plan-category-${item.$1?.name ?? 'all'}'),
          borderRadius: BorderRadius.circular(9),'''),
    ('''            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected == item.$1 ? p.surface : Colors.transparent,''', '''            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 9),
            decoration: BoxDecoration(
              color: selected == item.$1 ? p.lycheeSoft : Colors.transparent,'''),
    ('''            child: Text(item.$2, textAlign: TextAlign.center,
              style: TextStyle(color: selected == item.$1 ? p.lycheeInk : p.ink,''', '''            child: Text(item.$2, textAlign: TextAlign.center,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected == item.$1 ? p.lycheeInk : p.ink,'''),
    ('''          const SizedBox(height: 18),
          _CurrentPlanBadge(controller: controller),
          const SizedBox(height: 14),''', '''          const SizedBox(height: 14),
          _CurrentPlanBadge(controller: controller),
          const SizedBox(height: 12),'''),
    ('''          _CategoryDeck(selected: _category,
            onChanged: (value) => setState(() => _category = value)),
          const SizedBox(height: 14),''', '''          _CategoryDeck(selected: _category,
            onChanged: (value) => setState(() => _category = value)),
          const SizedBox(height: 12),'''),
])

account = 'lib/v3/pages/v3_account_page.dart'
modify(account, [
    ('''        const SizedBox(height: 26),
        _AccountSummaryPanel(controller: controller),
        const SizedBox(height: 16),
        _HubPanel(controller: controller),''', '''        const SizedBox(height: 16),
        _AccountSummaryPanel(controller: controller),
        const SizedBox(height: 12),
        _HubPanel(controller: controller),'''),
    ('''        if (AppConfig.panelFeatures.wallet || controller.user.balance > 0 ||
            controller.withdrawable > 0) ...[
          const SizedBox(height: 16),''', '''        if (AppConfig.panelFeatures.wallet || controller.user.balance > 0 ||
            controller.withdrawable > 0) ...[
          const SizedBox(height: 12),'''),
    ('''        const SizedBox(height: 16),
        _PreferencesPanel(controller: controller,''', '''        const SizedBox(height: 12),
        _PreferencesPanel(controller: controller,'''),
    ('''        const SizedBox(height: 16),
        _AccountActions(''', '''        const SizedBox(height: 12),
        _AccountActions('''),
    ('''      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.surface,''', '''      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.surface,'''),
    ('''        const SizedBox(height: 20),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 18),''', '''        const SizedBox(height: 16),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 14),'''),
    ('''      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.surfaceRaised,''', '''      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.surfaceRaised,'''),
    ('''    return Container(padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.surface,''', '''    return Container(padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.surface,'''),
])

for path, content in changes.items():
    Path(path).write_text(content, encoding='utf-8')
print('Migrated nodes, shop and account without changing controllers or API')

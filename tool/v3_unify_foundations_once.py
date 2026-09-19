"""One-shot, guarded V3 layout migration. Removed from the final PR by CI."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
changes = {}


def replace(path, old, new, count=1):
    if path not in changes:
        changes[path] = (ROOT / path).read_text(encoding='utf-8')
    content = changes[path]
    actual = content.count(old)
    if actual != count:
        raise RuntimeError(f'{path}: expected {count} match(es), found {actual}: {old[:85]!r}')
    changes[path] = content.replace(old, new)


layout = '''import 'package:flutter/material.dart';

import '../theme/v3_palette.dart';

/// Shared dimensions for the new Dashboard and the other V3 pages.
/// LayoutBuilder widths are local pane widths, not the overall window width.
abstract final class V3Layout {
  static const double pageGutter = 18;
  static const double cardRadius = 18;
  static const double cardGap = 12;
  static const EdgeInsets pageInsets = EdgeInsets.fromLTRB(18, 18, 18, 28);

  static bool canSplit({
    required double paneWidth,
    required double primaryMin,
    required double secondaryMin,
    double gap = cardGap,
  }) => paneWidth - pageGutter * 2 >= primaryMin + secondaryMin + gap;
}

/// Exactly the Dashboard's visual card: dark hero, independently light surface.
class V3WorkspaceCard extends StatelessWidget {
  const V3WorkspaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? p.hero : p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
'''

tests = '''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_layout.dart';

void main() {
  test('local 900x700 workspace can split traffic and invite', () {
    // 900 window - 200 rail - 12 right inset = 688 page pixels.
    expect(V3Layout.canSplit(
      paneWidth: 688, primaryMin: 340, secondaryMin: 270), isTrue);
    expect(V3Layout.canSplit(
      paneWidth: 688, primaryMin: 345, secondaryMin: 275, gap: 16), isTrue);
    expect(V3Layout.canSplit(
      paneWidth: 390, primaryMin: 340, secondaryMin: 270), isFalse);
    expect(V3Layout.canSplit(
      paneWidth: 360, primaryMin: 345, secondaryMin: 275, gap: 16), isFalse);
  });

  for (final dark in [false, true]) {
    testWidgets('workspace surface is theme-aware: ${dark ? 'dark' : 'light'}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        darkTheme: V3Theme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: const Scaffold(body: V3WorkspaceCard(child: Text('Litchi'))),
      ));
      final card = find.byType(V3WorkspaceCard);
      final decorated = tester.widget<DecoratedBox>(find.descendant(
        of: card, matching: find.byType(DecoratedBox)).first);
      final decoration = decorated.decoration as BoxDecoration;
      expect(decoration.color, dark ? V3Palette.dark.hero : V3Palette.light.surface);
      expect(decoration.borderRadius, BorderRadius.circular(18));
    });
  }
}
'''

# All replacement preconditions are checked before ANY existing file is written.
replace('lib/v3/pages/v3_dashboard_page.dart',
        "import '../ui/v3_node_tags.dart';\n", "import '../ui/v3_node_tags.dart';\nimport '../ui/v3_layout.dart';\n")
replace('lib/v3/pages/v3_dashboard_page.dart',
        '''  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? p.hero : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

const kConnectActionCardKey''',
        '''  @override
  Widget build(BuildContext context) =>
      V3WorkspaceCard(padding: padding, child: child);
}

const kConnectActionCardKey''')
replace('lib/v3/ui/v3_components.dart',
        '''              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              if (description != null) ...[
                const SizedBox(height: 7),''',
        '''              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              if (description != null) ...[
                const SizedBox(height: 6),''')

insets = {
    'lib/v3/pages/v3_nodes_page.dart': '24, 26, 24, 36',
    'lib/v3/pages/v3_account_page.dart': '24, 26, 24, 36',
    'lib/v3/pages/v3_invite_page.dart': '24, 26, 24, 36',
    'lib/v3/pages/v3_tickets_page.dart': '24, 26, 24, 36',
    'lib/v3/pages/v3_settings_page.dart': '24, 26, 24, 36',
    'lib/v3/pages/v3_traffic_page.dart': '24, 22, 24, 30',
}
for path, values in insets.items():
    replace(path, "import '../theme/v3_palette.dart';\n",
            "import '../theme/v3_palette.dart';\nimport '../ui/v3_layout.dart';\n")
    replace(path, f'padding: const EdgeInsets.fromLTRB({values}),',
            'padding: V3Layout.pageInsets,')

shop = 'lib/v3/pages/v3_shop_page.dart'
replace(shop, "import '../theme/v3_palette.dart';\n",
        "import '../theme/v3_palette.dart';\nimport '../ui/v3_layout.dart';\n")
replace(shop, 'const padding = 24.0;', 'const padding = V3Layout.pageGutter;')
replace(shop, 'padding: const EdgeInsets.fromLTRB(padding, 24, padding, 36),',
        'padding: V3Layout.pageInsets,')

traffic = 'lib/v3/pages/v3_traffic_page.dart'
replace(traffic, 'final compact = constraints.maxWidth < 760;',
        '''final compact = !V3Layout.canSplit(
        paneWidth: constraints.maxWidth, primaryMin: 340, secondaryMin: 270);''')
replace(traffic,
        '''    return Container(padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.hero,
        borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [''',
        '''    return V3WorkspaceCard(padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [''')
replace(traffic, 'borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),',
        'borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),', 1)
replace(traffic, 'borderRadius: BorderRadius.circular(22), border: Border.all(color: p.line)),',
        'borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),', 1)
# Once _QuotaPanel delegates to the shared card, its old local palette variable is unnecessary.
replace(traffic,
        '''class _QuotaPanel extends StatelessWidget {
  const _QuotaPanel({required this.controller, required this.usedRatio});
  final AppController controller;
  final double usedRatio;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);''',
        '''class _QuotaPanel extends StatelessWidget {
  const _QuotaPanel({required this.controller, required this.usedRatio});
  final AppController controller;
  final double usedRatio;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);''')

invite = 'lib/v3/pages/v3_invite_page.dart'
replace(invite, 'final compact = constraints.maxWidth < 760;',
        '''final compact = !V3Layout.canSplit(
        paneWidth: constraints.maxWidth, primaryMin: 345,
        secondaryMin: 275, gap: 16);''')
replace(invite,
        '''    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.hero,
        borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [''',
        '''    return V3WorkspaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [''')
replace(invite, 'radius: 26,', 'radius: V3Layout.cardRadius,', 2)
replace(invite, 'hero, const SizedBox(height: 16),',
        'hero, const SizedBox(height: V3Layout.cardGap),')
replace(invite, 'const SizedBox(height: 16),\n          _ReferralLedger(controller: controller),',
        'const SizedBox(height: V3Layout.cardGap),\n          _ReferralLedger(controller: controller),')

# Preserve the existing ticket list and skeleton. The desktop action belongs in
# its page header whenever the *inner* pane can comfortably show it.
replace('lib/v3/pages/v3_tickets_page.dart',
        'final compact = constraints.maxWidth < 760;',
        'final compact = constraints.maxWidth < 600;')
replace('lib/v3/pages/v3_tickets_page.dart',
        '''borderRadius: BorderRadius.circular(26),
              border: Border.all(color: p.line)),''',
        '''borderRadius: BorderRadius.circular(V3Layout.cardRadius),
              border: Border.all(color: p.line)),''')

settings = 'lib/v3/pages/v3_settings_page.dart'
replace(settings, 'color: selected ? p.surface : Colors.transparent,\n              borderRadius: BorderRadius.circular(9),',
        '''color: selected ? p.lycheeSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: selected ? p.lychee : Colors.transparent),''')
replace(settings, 'padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),',
        'padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),')

account = 'lib/v3/pages/v3_account_page.dart'
replace(account, 'borderRadius: BorderRadius.circular(26), border: Border.all(color: p.line)),',
        'borderRadius: BorderRadius.circular(V3Layout.cardRadius), border: Border.all(color: p.line)),', 2)
replace(account, '''decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(24)),''',
        '''decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line)),''')
replace(account, '''decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(20)),''',
        '''decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.line)),''')

# Render-related code only: no controller, API, route, subscription, Core or
# billing file is touched in this migration.
for path, content in changes.items():
    (ROOT / path).write_text(content, encoding='utf-8')
layout_path = ROOT / 'lib/v3/ui/v3_layout.dart'
test_path = ROOT / 'test/v3_layout_foundations_test.dart'
if layout_path.exists() or test_path.exists():
    raise RuntimeError('New layout/test file already exists; refusing overwrite')
layout_path.write_text(layout, encoding='utf-8')
test_path.write_text(tests, encoding='utf-8')
print(f'Applied guarded visual migration to {len(changes)} existing files plus 2 new files')

from pathlib import Path


def replace(path, old, new, expected=1):
    p = Path(path)
    source = p.read_text(encoding='utf-8')
    count = source.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected}, found {count}: {old[:100]!r}')
    p.write_text(source.replace(old, new), encoding='utf-8')

workspace = 'test/visual/v3_dashboard_workspace_test.dart'
replace(workspace, "import 'package:flutter/material.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';")
replace(workspace, "      await tester.binding.setSurfaceSize(size);", "      debugDefaultTargetPlatformOverride = TargetPlatform.windows;\n      addTearDown(() => debugDefaultTargetPlatformOverride = null);\n      await tester.binding.setSurfaceSize(size);")
replace(workspace, "    await tester.binding.setSurfaceSize(const Size(900, 700));", "    debugDefaultTargetPlatformOverride = TargetPlatform.windows;\n    addTearDown(() => debugDefaultTargetPlatformOverride = null);\n    await tester.binding.setSurfaceSize(const Size(900, 700));")

lychee = 'test/visual/v3_lychee_selection_test.dart'
replace(lychee, "import 'package:flutter/material.dart';", "import 'package:flutter/foundation.dart';\nimport 'package:flutter/material.dart';")
replace(lychee, "      await tester.binding.setSurfaceSize(const Size(900, 700));", "      debugDefaultTargetPlatformOverride = TargetPlatform.windows;\n      addTearDown(() => debugDefaultTargetPlatformOverride = null);\n      await tester.binding.setSurfaceSize(const Size(900, 700));")

practical = 'test/visual/v3_practical_ux_restore_test.dart'
replace(practical, "  bool get hasPlan => false;\n}", "  bool get hasPlan => false;\n  @override\n  bool get hasConfirmedNoPlan => true;\n}")
replace(practical, "class _RefreshFixture extends VisualV3Controller {", """// Unknown plan state must not be treated as a confirmed negative.
class _UnknownPlanFixture extends VisualV3Controller {
  _UnknownPlanFixture() : super(AppPage.dashboard);
  @override
  bool get hasPlan => false;
  @override
  bool get hasConfirmedNoPlan => false;
}

class _RefreshFixture extends VisualV3Controller {""")
needle = "  test('desktop-only settings are hidden on mobile and Linux', () {"
assert needle in Path(practical).read_text(encoding='utf-8')
replace(practical, needle, """  testWidgets('unknown plan status keeps normal cards without purchase warning',
      (tester) async {
    final fixture = _UnknownPlanFixture();
    addTearDown(fixture.disposeVisual);
    await tester.pumpWidget(AppScope(
      controller: fixture,
      child: MaterialApp(theme: V3Theme.light(),
        home: const Scaffold(body: V3DashboardPage())),
    ));
    expect(find.text('当前没有可用套餐'), findsNothing);
    expect(find.byKey(kConnectActionCardKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

""" + needle)

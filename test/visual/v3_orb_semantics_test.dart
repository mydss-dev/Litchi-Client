import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/semantics.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/pages/v3_dashboard_page.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

/// Round-3 audit F02: the connect orb is the page's primary control, and
/// assistive tech must fire exactly what a tap fires. ExcludeSemantics prunes
/// the inner InkWell's own semantics, so the tap action has to live on the
/// outer labeled node — this test holds that contract.
void main() {
  testWidgets('the connect orb exposes a tap action with the connected label', (
    tester,
  ) async {
    // The orb lives in the desktop connection workspace. The override and the
    // semantics handle are both cleared in the body: the framework checks
    // foundation invariants and leaked handles before tear-downs run.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final semantics = tester.ensureSemantics();
    try {
      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = VisualV3Controller(AppPage.dashboard);
      addTearDown(controller.disposeVisual);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: V3Theme.light(),
            home: const Scaffold(body: V3DashboardPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SemanticsNode orb = tester.getSemantics(
        find.byKey(kConnectOrbKey),
      );
      final data = orb.getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue,
          reason: 'the orb must carry its tap action on the labeled node');
      expect(data.label, '断开连接',
          reason: 'the fixture is connected, so the label names what a tap does');
      expect(data.flagsCollection.isButton, isTrue);
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

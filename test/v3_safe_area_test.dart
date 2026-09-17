import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'visual/v3_visual_fixture.dart';

/// Fake a notched Android device: ordinary zero-inset widget surfaces cannot
/// reveal whether page content paints beneath the status and gesture bars.
class _Controller extends VisualV3Controller {
  _Controller(super.page, {this.authed = true});
  final bool authed;
  @override
  bool get isAuthenticated => authed;
}

const double _statusBar = 48;
const double _gestureBar = 48;
const Size _phone = Size(390, 844);

Future<void> _pump(WidgetTester tester, AppPage page, {bool authed = true}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _phone;
  tester.view.padding = const FakeViewPadding(top: _statusBar, bottom: _gestureBar);
  addTearDown(tester.view.reset);
  final controller = _Controller(page, authed: authed);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(MaterialApp(
    theme: V3Theme.light(),
    home: AppScope(controller: controller, child: const V3Shell()),
  ));
  await tester.pumpAndSettle();
}

/// Find one *element*, not a canonical const Text widget: when a label appears
/// on three plan cards, find.byWidget(element.widget) matches all three.
Finder _exactElement(Element element) =>
    find.byElementPredicate((candidate) => identical(candidate, element));

void main() {
  final pages = <AppPage>[
    for (final item in <V3NavItem>[...kMobilePrimary, ...kMobileHub]) item.page,
  ];
  for (final page in pages) {
    testWidgets('${page.name} clears the Android status bar', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pump(tester, page);
        for (final element in find.byType(Text).evaluate()) {
          final rect = tester.getRect(_exactElement(element));
          expect(rect.top, greaterThanOrEqualTo(_statusBar), reason:
            'text ${(element.widget as Text).data ?? ""} renders at '
            '${rect.top}dp, under the ${_statusBar}dp status bar');
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('the login screen clears the Android status bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pump(tester, AppPage.dashboard, authed: false);
      for (final element in find.byType(Text).evaluate()) {
        final rect = tester.getRect(_exactElement(element));
        expect(rect.top, greaterThanOrEqualTo(_statusBar), reason:
          'login text ${(element.widget as Text).data ?? ""} renders at '
          '${rect.top}dp, under the ${_statusBar}dp status bar');
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the bottom bar clears the gesture bar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pump(tester, AppPage.dashboard);
      final nav = find.byType(NavigationBar);
      final rect = tester.getRect(nav);
      for (final element in
          find.descendant(of: nav, matching: find.byType(Text)).evaluate()) {
        final label = tester.getRect(_exactElement(element));
        expect(label.bottom, lessThanOrEqualTo(_phone.height - _gestureBar),
          reason: 'nav label sits under the ${_gestureBar}dp gesture bar');
      }
      expect(rect.bottom, lessThanOrEqualTo(_phone.height));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

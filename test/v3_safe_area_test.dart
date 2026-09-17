import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_nav.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'visual/v3_visual_fixture.dart';

/// Assert safe-area clearance for the actual text elements. Looking up each
/// Text widget by identity is ambiguous when repeated plan cards reuse a const
/// label; the Element, unlike that immutable widget, is unique in the tree.
class _Controller extends VisualV3Controller {
  _Controller(super.page, {this.authed = true});
  final bool authed;

  @override
  bool get isAuthenticated => authed;
}

const double _statusBar = 48;
const double _gestureBar = 48;
const Size _phone = Size(390, 844);

Future<void> _pump(
  WidgetTester tester,
  AppPage page, {
  bool authed = true,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _phone;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);

  final controller = _Controller(page, authed: authed);
  addTearDown(controller.disposeVisual);
  await tester.pumpWidget(MaterialApp(
    theme: V3Theme.light(),
    home: AppScope(controller: controller, child: const V3Shell()),
  ));
  await tester.pumpAndSettle();
}

/// A finder anchored to one Element avoids collisions between identical Text
/// widgets (e.g. '查看完整说明' on three plan cards).
Finder _elementFinder(Element element) =>
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
          final rect = tester.getRect(_elementFinder(element));
          expect(
            rect.top,
            greaterThanOrEqualTo(_statusBar),
            reason:
                'text ${(element.widget as Text).data ?? ""} renders at '
                '${rect.top}dp, under the ${_statusBar}dp status bar',
          );
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
        final rect = tester.getRect(_elementFinder(element));
        expect(
          rect.top,
          greaterThanOrEqualTo(_statusBar),
          reason:
              'login text ${(element.widget as Text).data ?? ""} renders at '
              '${rect.top}dp, under the ${_statusBar}dp status bar',
        );
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
      // The nav's own box can extend into the gesture inset; its text cannot.
      for (final element
          in find.descendant(of: nav, matching: find.byType(Text)).evaluate()) {
        final label = tester.getRect(_elementFinder(element));
        expect(
          label.bottom,
          lessThanOrEqualTo(_phone.height - _gestureBar),
          reason: 'nav label sits under the ${_gestureBar}dp gesture bar',
        );
      }
      expect(rect.bottom, lessThanOrEqualTo(_phone.height));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

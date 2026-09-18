import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'v3_visual_fixture.dart';

const _visualSnapshotsEnabled = bool.fromEnvironment('LITCHI_VISUAL_SNAPSHOTS');

const _pages = <(AppPage, String)>[
  (AppPage.dashboard, 'dashboard'),
  (AppPage.nodes, 'nodes'),
  (AppPage.shop, 'shop'),
  (AppPage.account, 'account'),
  (AppPage.invite, 'invite'),
  (AppPage.traffic, 'traffic'),
  (AppPage.orders, 'orders'),
  (AppPage.tickets, 'tickets'),
  (AppPage.settings, 'settings'),
  (AppPage.more, 'more'),
  (AppPage.giftCard, 'giftCard'),
];

/// The same fixture, signed out — enough to reach [V3AuthView].
class _SignedOutController extends VisualV3Controller {
  _SignedOutController() : super(AppPage.dashboard);

  @override
  bool get isAuthenticated => false;
}

void main() {
  for (final item in _pages) {
    final (page, name) = item;

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final themeName = themeMode == ThemeMode.light ? 'light' : 'dark';

      testWidgets('V3 Windows 900x700 $name $themeName visual', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await _pumpV3(
            tester,
            size: const Size(900, 700),
            themeMode: themeMode,
            page: page,
          );
          if (_visualSnapshotsEnabled) {
            await expectLater(
              find.byType(V3Shell),
              matchesGoldenFile(
                'goldens/v3_windows_${name}_${themeName}_900x700.png',
              ),
            );
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });

      testWidgets('V3 Android 390x844 $name $themeName visual', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await _pumpV3(
            tester,
            size: const Size(390, 844),
            themeMode: themeMode,
            page: page,
          );
          if (_visualSnapshotsEnabled) {
            await expectLater(
              find.byType(V3Shell),
              matchesGoldenFile(
                'goldens/v3_android_${name}_${themeName}_390x844.png',
              ),
            );
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('V3 Android 360x800 $name compact smoke', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await _pumpV3(
          tester,
          size: const Size(360, 800),
          themeMode: ThemeMode.light,
          page: page,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(V3Shell), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  // The login screen has its own brand block, which was the largest of the
  // near-black panels in light mode. It is not part of the page loop above,
  // so it had no visual coverage at all.
  for (final login in <(String, Size, TargetPlatform)>[
    ('windows', const Size(900, 700), TargetPlatform.windows),
    ('android', const Size(390, 844), TargetPlatform.android),
  ]) {
    final (platformName, size, platform) = login;
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final themeName = themeMode == ThemeMode.light ? 'light' : 'dark';
      testWidgets('V3 $platformName login $themeName visual', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await _pumpSignIn(tester, size: size, themeMode: themeMode);
          if (_visualSnapshotsEnabled) {
            await expectLater(
              find.byType(V3Shell),
              matchesGoldenFile(
                'goldens/v3_${platformName}_login_${themeName}_'
                '${size.width.toInt()}x${size.height.toInt()}.png',
              ),
            );
          }
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}

Future<void> _pumpV3(
  WidgetTester tester, {
  required Size size,
  required ThemeMode themeMode,
  required AppPage page,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = VisualV3Controller(page);
  addTearDown(controller.disposeVisual);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: V3Theme.light(),
      darkTheme: V3Theme.dark(),
      themeMode: themeMode,
      home: AppScope(controller: controller, child: const V3Shell()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 360));
  await tester.pump();
  expect(tester.takeException(), isNull);
}

Future<void> _pumpSignIn(
  WidgetTester tester, {
  required Size size,
  required ThemeMode themeMode,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final controller = _SignedOutController();
  addTearDown(controller.disposeVisual);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: V3Theme.light(),
      darkTheme: V3Theme.dark(),
      themeMode: themeMode,
      home: AppScope(controller: controller, child: const V3Shell()),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
}

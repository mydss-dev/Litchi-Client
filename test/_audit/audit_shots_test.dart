import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import '../visual/v3_visual_fixture.dart';

class _Nav extends VisualV3Controller {
  _Nav(super.initial) : _c = initial;
  AppPage _c;
  @override
  AppPage get page => _c;
  @override
  void goToPage(AppPage next) { _c = next; notifyListeners(); }
}

Future<void> _loadFont(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    final f = File(p);
    if (f.existsSync()) l.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await l.load();
}

void main() {
  setUpAll(() async {
    const fam = ['Segoe UI','Segoe UI Variable','SF Pro Text','Microsoft YaHei UI','Roboto','Noto Sans','Noto Sans CJK SC'];
    for (final f in fam) { await _loadFont(f, ['C:/Windows/Fonts/msyh.ttc']); }
    // Package icon fonts
    final manifest = File('build/unit_test_assets/FontManifest.json');
    if (manifest.existsSync()) {
      final txt = manifest.readAsStringSync();
      final re = RegExp(r'"family":"([^"]+)","fonts":\[\{"asset":"([^"]+)"');
      for (final m in re.allMatches(txt)) {
        await _loadFont(m.group(1)!, ['build/unit_test_assets/${m.group(2)}']);
      }
    }
  });
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final page in AppPage.values) {
      testWidgets('audit ${mode.name} ${page.name}', (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = const Size(1080, 2340); // 360x780
        addTearDown(() { debugDefaultTargetPlatformOverride = null; tester.view.reset(); });
        final c = _Nav(page);
        addTearDown(c.disposeVisual);
        await tester.pumpWidget(RepaintBoundary(key: const ValueKey('cap'), child: AppScope(controller: c, child: MaterialApp(
          debugShowCheckedModeBanner: false, locale: const Locale('zh'),
          theme: V3Theme.light(), darkTheme: V3Theme.dark(), themeMode: mode, home: const V3Shell()))));
        await tester.pump(); await tester.pump(const Duration(milliseconds: 1200)); await tester.pump();
        tester.takeException();
        await expectLater(find.byKey(const ValueKey('cap')), matchesGoldenFile('shots/${mode.name}_${page.index.toString().padLeft(2,'0')}_${page.name}.png'));
      });
    }
  }
}

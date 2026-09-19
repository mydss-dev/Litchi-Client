import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/app_controller.dart';
import 'package:litchi_client/v3/app/v3_shell.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';

import 'visual/v3_visual_fixture.dart';

void main() {
  test('desktop app does not lock the OS font scale to 100 percent', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    expect(source, isNot(contains('MediaQuery.withClampedTextScaling')));
    expect(source, isNot(contains('textScaler: const TextScaler.linear(1)')));
  });

  testWidgets('V3 desktop shell inherits an enlarged OS font setting',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    final controller = VisualV3Controller(AppPage.nodes);
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
      controller.disposeVisual();
    });

    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(1.25),
        ),
        child: child!,
      ),
      home: AppScope(controller: controller, child: const V3Shell()),
    ));
    await tester.pumpAndSettle();
    final workspace = find.text('工作空间');
    expect(workspace, findsOneWidget);
    final scaler = MediaQuery.textScalerOf(tester.element(workspace));
    expect(scaler.scale(13), closeTo(16.25, 0.01));
    expect(tester.takeException(), isNull);
  });
}

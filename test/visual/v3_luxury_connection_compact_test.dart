import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_luxury_connect_stage.dart';
import 'package:litchi_client/v3/ui/v3_luxury_surface.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      testWidgets('luxury connect 5 states fit ${width.toInt()}dp '
          '${dark ? 'dark' : 'light'}', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final up = ValueNotifier<int>(2 * 1024 * 1024);
        final down = ValueNotifier<int>(6 * 1024 * 1024);
        final session = ValueNotifier<int>(3 * 1024 * 1024);
        addTearDown(up.dispose);
        addTearDown(down.dispose);
        addTearDown(session.dispose);

        for (final status in ConnectionStatus.values) {
          await tester.pumpWidget(MaterialApp(
            theme: V3Theme.light(),
            darkTheme: V3Theme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(body: V3LuxuryBackdrop(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(children: [
                    V3LuxuryConnectionHero(
                      status: status,
                      locked: false,
                      onToggle: () {},
                      nodeCode: 'HK',
                      nodeName: '香港 · 中环 01 Premium Extra Long',
                      nodeLatencyMs: 32,
                      connectedDuration: const Duration(hours: 10),
                      upBps: up,
                      downBps: down,
                    ),
                    const SizedBox(height: 18),
                    V3LuxurySessionMetrics(
                      status: status,
                      upBps: up,
                      downBps: down,
                      sessionBytes: session,
                    ),
                  ]),
                ),
              ),
            )),
          ));
          await tester.pump(const Duration(milliseconds: 260));
          expect(tester.takeException(), isNull,
            reason: 'layout error at ${width.toInt()}dp in '
              '$status / ${dark ? 'dark' : 'light'}');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

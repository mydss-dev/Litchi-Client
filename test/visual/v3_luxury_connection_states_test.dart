import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/app/core_controller.dart' show ConnectionStatus;
import 'package:litchi_client/v3/theme/v3_luxury_tokens.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_luxury_connect_stage.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('all connection variants and session-zeroing / '
        '${dark ? 'dark' : 'light'}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final up = ValueNotifier<int>(5 * 1024 * 1024);
      final down = ValueNotifier<int>(12 * 1024 * 1024);
      final session = ValueNotifier<int>(9 * 1024 * 1024);
      addTearDown(up.dispose);
      addTearDown(down.dispose);
      addTearDown(session.dispose);
      var actions = 0;
      final colors = dark ? V3LuxuryTokens.dark : V3LuxuryTokens.light;

      Future<void> draw(ConnectionStatus status) async {
        await tester.pumpWidget(MaterialApp(
          theme: V3Theme.light(),
          darkTheme: V3Theme.dark(),
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                V3LuxuryConnectionHero(
                  status: status,
                  locked: false,
                  onToggle: () => actions++,
                  nodeCode: 'HK',
                  nodeName: '香港 · 中环 01',
                  nodeLatencyMs: 32,
                  readConnectedDuration: () => const Duration(minutes: 42, seconds: 18),
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
          )),
        ));
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Real nonzero ValueNotifiers must be ignored unless status is
      // connected, even if the previous session left stale byte counters.
      await draw(ConnectionStatus.disconnected);
      expect(find.text('立即连接'), findsOneWidget);
      expect(find.text('00:00:00'), findsOneWidget);
      expect(find.text('0 B/s'), findsNWidgets(2));
      expect(find.text('0 MB'), findsOneWidget);
      var face = tester.widget<AnimatedContainer>(
        find.byKey(const Key('v3-luxury-orb-face')));
      expect((face.decoration as BoxDecoration).color, colors.surfaceStrong);
      expect(((face.decoration as BoxDecoration).border as Border).top.color,
        colors.gold);
      await tester.tap(find.byKey(const Key('v3-luxury-orb-action')));
      expect(actions, 1);

      await draw(ConnectionStatus.connecting);
      expect(find.text('连接中…'), findsOneWidget);
      expect(find.byKey(const Key('v3-luxury-orb-loading')),
        findsOneWidget);
      expect(find.text('--:--:--'), findsOneWidget);
      expect(find.text('0 B/s'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('v3-luxury-orb-action')));
      expect(actions, 1, reason: 'busy action must be disabled');

      await draw(ConnectionStatus.error);
      expect(find.text('连接失败'), findsOneWidget);
      face = tester.widget<AnimatedContainer>(
        find.byKey(const Key('v3-luxury-orb-face')));
      expect(((face.decoration as BoxDecoration).border as Border).top.color,
        colors.danger);
      expect(find.text('0 MB'), findsOneWidget);
      expect(find.text('0 B/s'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('v3-luxury-orb-action')));
      expect(actions, 2, reason: 'retry reuses the same connection callback');

      await draw(ConnectionStatus.connected);
      expect(find.text('已保护'), findsOneWidget);
      expect(find.text('00:42:18'), findsOneWidget);
      expect(find.text('断开连接'), findsOneWidget);
      expect(find.text('12.0 MB/s'), findsOneWidget);
      expect(find.text('5.0 MB/s'), findsOneWidget);
      expect(find.text('9.0 MB'), findsOneWidget);
      face = tester.widget<AnimatedContainer>(
        find.byKey(const Key('v3-luxury-orb-face')));
      expect((face.decoration as BoxDecoration).color, colors.orbFace);
      await tester.tap(find.byKey(const Key('v3-luxury-orb-action')));
      expect(actions, 3);

      // Transition back out: no stale session values in the UI.
      await draw(ConnectionStatus.disconnecting);
      expect(find.byKey(const Key('v3-luxury-orb-loading')),
        findsOneWidget);
      expect(find.text('0 B/s'), findsNWidgets(2));
      expect(find.text('0 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

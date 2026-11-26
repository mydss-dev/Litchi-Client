import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_luxury_tokens.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_luxury_surface.dart';

void main() {
  test('design tokens keep green status separate from gold selection', () {
    expect(V3LuxuryTokens.dark.gold, const Color(0xFFE8C269));
    expect(V3LuxuryTokens.light.gold, const Color(0xFFA88033));
    expect(V3LuxuryTokens.dark.success, const Color(0xFF7DD9A6));
    expect(V3LuxuryTokens.light.success, const Color(0xFF178759));
    expect(V3LuxuryTokens.dark.gold, isNot(V3LuxuryTokens.dark.success));
    expect(V3LuxuryTokens.light.gold, isNot(V3LuxuryTokens.light.success));
    expect(V3LuxuryTokens.light.orbFace, const Color(0xFF171C21));
    expect(V3LuxuryRadius.card, 24);
    expect(V3LuxurySpacing.pageHorizontal, 20);
  });

  testWidgets('existing theme switch selects correct luxury extension', (
    tester,
  ) async {
    Future<void> show(ThemeMode mode) async {
      await tester.pumpWidget(MaterialApp(
        theme: V3Theme.light(),
        darkTheme: V3Theme.dark(),
        themeMode: mode,
        home: Builder(builder: (context) {
          final c = V3LuxuryTokens.of(context);
          return Scaffold(body: Center(child: Text(
            c.gold == V3LuxuryTokens.light.gold ? 'light' : 'dark',
          )));
        }),
      ));
      // ThemeData is applied through AnimatedTheme; allow its default
      // transition to settle before checking the resolved extension.
      await tester.pumpAndSettle();
    }

    await show(ThemeMode.light);
    expect(find.text('light'), findsOneWidget);
    await show(ThemeMode.dark);
    expect(find.text('dark'), findsOneWidget);
  });

  testWidgets('glass backdrop renders without intercepting taps', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      theme: V3Theme.light(),
      home: Scaffold(
        body: V3LuxuryBackdrop(
          child: Center(
            child: V3LuxuryGlassCard(
              child: TextButton(
                onPressed: () => tapped++,
                child: const Text('Tap'),
              ),
            ),
          ),
        ),
      ),
    ));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('Tap'));
    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });
}

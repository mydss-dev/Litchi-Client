import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_layout.dart';

void main() {
  test('local 900x700 workspace can split traffic and invite', () {
    // 900 window - 200 rail - 12 right inset = 688 page pixels.
    expect(
      V3Layout.canSplit(paneWidth: 688, primaryMin: 340, secondaryMin: 270),
      isTrue,
    );
    expect(
      V3Layout.canSplit(
        paneWidth: 688,
        primaryMin: 345,
        secondaryMin: 275,
        gap: 16,
      ),
      isTrue,
    );
    expect(
      V3Layout.canSplit(paneWidth: 390, primaryMin: 340, secondaryMin: 270),
      isFalse,
    );
    expect(
      V3Layout.canSplit(
        paneWidth: 360,
        primaryMin: 345,
        secondaryMin: 275,
        gap: 16,
      ),
      isFalse,
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'workspace surface is theme-aware: ${dark ? 'dark' : 'light'}',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: V3Theme.light(),
            darkTheme: V3Theme.dark(),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: const Scaffold(body: V3WorkspaceCard(child: Text('Litchi'))),
          ),
        );
        final card = find.byType(V3WorkspaceCard);
        final decorated = tester.widget<DecoratedBox>(
          find.descendant(of: card, matching: find.byType(DecoratedBox)).first,
        );
        final decoration = decorated.decoration as BoxDecoration;
        expect(
          decoration.color,
          dark ? V3Palette.dark.hero : V3Palette.light.surface,
        );
        expect(decoration.borderRadius, BorderRadius.circular(18));
      },
    );
  }
}

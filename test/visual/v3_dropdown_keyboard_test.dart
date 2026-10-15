import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/v3/theme/v3_palette.dart';
import 'package:litchi_client/v3/ui/v3_dropdown.dart';

/// Round-3 audit F01: the dropdown trigger is a real keyboard control — Tab
/// reaches it, Enter opens, arrow keys open straight onto an entry, and a
/// selection closes the menu. These tests pin that path on the shared
/// [V3Dropdown] so a settings-row refactor cannot strand keyboard users.
void main() {
  const items = <String>['auto', 'manual'];
  String label(String value) => value == 'auto' ? '自动选择' : '手动选择';

  Future<void> pumpDropdown(
    WidgetTester tester, {
    required ValueChanged<String> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: V3Theme.light(),
        home: Scaffold(
          body: Center(
            child: V3Dropdown<String>(
              value: 'auto',
              items: items,
              label: label,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Tab focuses the trigger and Enter opens the menu', (tester) async {
    String? selected;
    await pumpDropdown(tester, onChanged: (v) => selected = v);

    // Menu closed: the second entry only exists inside the open menu.
    expect(find.text('手动选择'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('手动选择'), findsOneWidget,
        reason: 'Enter on the focused trigger opens the menu');
    expect(selected, isNull, reason: 'opening alone selects nothing');
  });

  testWidgets('arrowDown moves focus into the items and Enter selects', (
    tester,
  ) async {
    String? selected;
    await pumpDropdown(tester, onChanged: (v) => selected = v);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected, 'auto',
        reason: 'the focused item answers Enter like a tap would');
    expect(find.text('手动选择'), findsNothing,
        reason: 'a selection closes the menu');
  });

  testWidgets('Escape closes the open menu', (tester) async {
    await pumpDropdown(tester, onChanged: (_) {});

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('手动选择'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('手动选择'), findsNothing,
        reason: 'Escape on the focused trigger closes the open menu');
  });
}

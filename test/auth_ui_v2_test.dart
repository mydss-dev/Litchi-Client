import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:litchi_client/features/auth/widgets/auth_form_parts.dart';
import 'package:litchi_client/features/auth/widgets/auth_input.dart';
import 'package:litchi_client/features/auth/widgets/auth_primary_button.dart';

void main() {
  testWidgets('AuthPrimaryButton delegates loading and press behavior', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthPrimaryButton(label: 'Login', onPressed: () => taps++),
        ),
      ),
    );

    await tester.tap(find.text('Login'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthPrimaryButton(
            label: 'Login',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Login'));
    expect(taps, 1);
  });

  testWidgets('AuthInput preserves password reveal behavior', (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthInput(
            icon: LucideIcons.lock,
            hintText: 'Password',
            controller: controller,
            obscure: true,
            showRevealToggle: true,
          ),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.byIcon(LucideIcons.eyeOff));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
  });

  testWidgets('AuthCheckboxRow keeps its compatibility callback', (tester) async {
    bool? nextValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthCheckboxRow(
            value: false,
            label: 'Remember',
            onChanged: (value) => nextValue = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Remember'));
    expect(nextValue, isTrue);
  });
}

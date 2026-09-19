import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V3 visual layer never imports legacy UI', () {
    final root = Directory('lib/v3');
    expect(root.existsSync(), isTrue, reason: 'V3 visual root must exist');

    final violations = <String>[];
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      const forbidden = <String>[
        '/features/',
        'app_shell.dart',
        '/shared/widgets/',
        '/shared/layout/',
      ];
      for (final pattern in forbidden) {
        if (source.contains(pattern)) {
          violations.add(
            '${entity.path} imports forbidden legacy UI pattern: $pattern',
          );
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Rule #1: V3 must rebuild presentation from scratch and may only reuse business/state infrastructure.',
    );
  });

  test('legacy presentation layer is physically removed', () {
    expect(Directory('lib/features').existsSync(), isFalse);
    expect(Directory('lib/shared/widgets').existsSync(), isFalse);
    expect(Directory('lib/shared/layout').existsSync(), isFalse);
    expect(File('lib/app/app_shell.dart').existsSync(), isFalse);
    expect(File('lib/app/app_window_bar.dart').existsSync(), isFalse);
  });

  test('app root renders V3 instead of legacy AppShell', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    expect(source.contains('../v3/app/v3_shell.dart'), isTrue);
    expect(source.contains('V3Shell('), isTrue);
    expect(source.contains('app_shell.dart'), isFalse);
    expect(source.contains('AppShell('), isFalse);
  });

  test('the payment dialog is implemented exactly once', () {
    // The checkout and payment dialog must each have one owner. A translated
    // label belongs in localization data and must not count as a second dialog.
    final v3 = Directory('lib/v3');
    final checkoutOwners = <String>[];
    final dialogOwners = <String>[];

    for (final entity in v3.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      final name = entity.uri.pathSegments.last;
      if (source.contains('checkoutOrder(')) checkoutOwners.add(name);
      if (source.contains('extends StatefulWidget') &&
          source.contains('class _V3PaymentDialog ')) {
        dialogOwners.add(name);
      }
    }

    expect(checkoutOwners, [
      'v3_payment_flow.dart',
    ], reason: 'only the shared payment flow may drive a checkout');
    expect(dialogOwners, [
      'v3_payment_flow.dart',
    ], reason: 'only the shared payment flow may present the payment dialog');
  });

  test('repository instruction keeps clean V3 rule first', () {
    final source = File('AGENTS.md').readAsStringSync();
    final ruleIndex = source.indexOf(
      'NON-NEGOTIABLE: DO NOT REUSE OR MIX LEGACY UI',
    );
    final architectureIndex = source.indexOf('V3 Architecture Boundary');
    expect(ruleIndex, greaterThanOrEqualTo(0));
    expect(architectureIndex, greaterThan(ruleIndex));
  });
}

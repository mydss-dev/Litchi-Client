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
      final forbidden = <String>[
        '/features/',
        "app_shell.dart'",
        '/shared/widgets/',
      ];
      for (final pattern in forbidden) {
        if (source.contains(pattern)) {
          violations.add('${entity.path} imports forbidden legacy UI pattern: $pattern');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Rule #1: V3 must rebuild presentation from scratch and may only reuse business/state infrastructure.',
    );
  });

  test('app root renders V3 instead of legacy AppShell', () {
    final source = File('lib/app/app.dart').readAsStringSync();
    expect(source, contains('../v3/app/v3_shell.dart'));
    expect(source, contains('V3Shell('));
    expect(source, isNot(contains("import 'app_shell.dart'")));
    expect(source, isNot(contains('body: AppShell(')));
  });

  test('repository instruction keeps clean V3 rule first', () {
    final source = File('AGENTS.md').readAsStringSync();
    final ruleIndex = source.indexOf('NON-NEGOTIABLE: DO NOT REUSE OR MIX LEGACY UI');
    final architectureIndex = source.indexOf('V3 Architecture Boundary');
    expect(ruleIndex, greaterThanOrEqualTo(0));
    expect(architectureIndex, greaterThan(ruleIndex));
  });
}

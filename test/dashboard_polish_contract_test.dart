import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard polish hierarchy stays intentional', () {
    final workspace = File(
      'lib/features/dashboard/widgets/greenfield_connection_workspace.dart',
    ).readAsStringSync();
    final surfaces = File(
      'lib/features/dashboard/widgets/greenfield_dashboard_surfaces.dart',
    ).readAsStringSync();

    expect(workspace, contains('height: compact ? null : 232'));
    expect(workspace, isNot(contains('height: compact ? null : 248')));
    expect(workspace, contains('shadow: AppCardShadow.soft'));
    expect(workspace, contains('mainAxisAlignment: MainAxisAlignment.center'));
    expect(workspace, contains('width: 188'));

    expect(surfaces, contains('height: compact ? null : 92'));
    expect(
      RegExp(r'shadow: AppCardShadow\.none').allMatches(surfaces).length,
      greaterThanOrEqualTo(2),
    );
  });
}

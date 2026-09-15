import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('TrafficPage delegates entirely to GreenfieldTrafficPage', () {
    final source = File(
      'lib/features/traffic/traffic_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'greenfield_traffic_page.dart';"));
    expect(
      source,
      contains('Widget build(BuildContext context) => const GreenfieldTrafficPage();'),
    );
    expect(source, isNot(contains('CorePlatformSupport')));
    expect(source, isNot(contains('_DesktopTrafficSummary')));
    expect(source, isNot(contains('_StatsGrid')));
  });

  test('greenfield traffic surface keeps a stable runtime marker', () {
    final source = File(
      'lib/features/traffic/widgets/greenfield_traffic_surface.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('greenfield-traffic-surface')"));
    expect(source, contains('AppPlatform.usesTouch'));
  });
}

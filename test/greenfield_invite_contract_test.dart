import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InvitePage delegates entirely to GreenfieldInvitePage', () {
    final source = File(
      'lib/features/invite/invite_page.dart',
    ).readAsStringSync();

    expect(source, contains("import 'greenfield_invite_page.dart';"));
    expect(
      source,
      contains('Widget build(BuildContext context) => const GreenfieldInvitePage();'),
    );
    expect(source, isNot(contains('CorePlatformSupport')));
    expect(source, isNot(contains('PageController')));
  });

  test('greenfield invite surface keeps a stable runtime marker', () {
    final source = File(
      'lib/features/invite/widgets/greenfield_invite_surface.dart',
    ).readAsStringSync();

    expect(source, contains("ValueKey('greenfield-invite-surface')"));
  });
}

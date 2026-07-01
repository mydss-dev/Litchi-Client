import 'package:flutter_test/flutter_test.dart';

import '../tool/apply_branding.dart' show sanitizeWindowsExecutableBaseName;

void main() {
  test('keeps valid Unicode white-label executable names', () {
    expect(sanitizeWindowsExecutableBaseName('荔枝 VPN'), '荔枝 VPN');
  });

  test('sanitizes invalid and reserved Windows executable names', () {
    expect(sanitizeWindowsExecutableBaseName('测试/A:B?'), '测试_A_B_');
    expect(sanitizeWindowsExecutableBaseName('CON'), 'CON-App');
    expect(sanitizeWindowsExecutableBaseName('***'), '___');
    expect(sanitizeWindowsExecutableBaseName('...'), 'Client-App');
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/sing_box_ffi.dart';

void main() {
  test('desktop library candidates use the platform library extension', () {
    final candidates = SingBoxFfi.libraryCandidates();
    expect(candidates, isNotEmpty);
    if (Platform.isWindows) {
      expect(candidates.every((path) => path.endsWith('.dll')), isTrue);
    } else if (Platform.isMacOS) {
      expect(candidates.every((path) => path.endsWith('.dylib')), isTrue);
    } else if (Platform.isLinux) {
      expect(candidates.every((path) => path.endsWith('.so')), isTrue);
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/services/sing_box_ffi.dart';

void main() {
  test('desktop library candidates match supported FFI platforms', () {
    final candidates = SingBoxFfi.libraryCandidates();
    if (Platform.isWindows) {
      expect(SingBoxFfi.isSupported, isFalse);
      expect(candidates, isEmpty);
    } else if (Platform.isMacOS) {
      expect(SingBoxFfi.isSupported, isTrue);
      expect(candidates, isNotEmpty);
      expect(candidates.every((path) => path.endsWith('.dylib')), isTrue);
    } else if (Platform.isLinux) {
      expect(SingBoxFfi.isSupported, isTrue);
      expect(candidates, isNotEmpty);
      expect(candidates.every((path) => path.endsWith('.so')), isTrue);
    }
  });
}

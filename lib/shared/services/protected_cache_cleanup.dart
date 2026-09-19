import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Removes the platform-secure payload behind a cache's on-disk reference.
/// Windows DPAPI keeps its protected blob in the cache file instead, so file
/// deletion is sufficient there. Linux never persists protected payloads.
abstract final class ProtectedCacheCleanup {
  static Future<void> deleteSlot(String slot) async {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) return;
    await const FlutterSecureStorage().delete(key: slot);
  }
}

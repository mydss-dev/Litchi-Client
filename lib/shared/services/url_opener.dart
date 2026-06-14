import 'dart:io';

import 'package:flutter/services.dart';

abstract final class UrlOpener {
  static const _channel = MethodChannel('litchi/url_opener');

  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }

    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<bool>('openUrl', url) ?? false;
      }
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', url]);
        return result.exitCode == 0;
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', [url]);
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        return result.exitCode == 0;
      }
    } catch (_) {}
    return false;
  }
}

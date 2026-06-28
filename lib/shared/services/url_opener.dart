import 'dart:io';

import 'package:flutter/services.dart';

import 'secure_logger.dart';
import 'windows_shell.dart';

abstract final class UrlOpener {
  static const _channel = MethodChannel('litchi/url_opener');

  static Future<bool> open(String url) async {
    if (!_isSafeExternalUrl(url)) return false;

    try {
      if (Platform.isAndroid) {
        return await _channel.invokeMethod<bool>('openUrl', url) ?? false;
      }
      if (Platform.isWindows) {
        return shellExecuteUrl(url);
      }
      if (Platform.isMacOS) {
        final result = await Process.run('open', [url]);
        return result.exitCode == 0;
      }
      if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [url]);
        return result.exitCode == 0;
      }
    } catch (e) {
      SecureLogger.debug('URL open failed', e);
    }
    return false;
  }

  static bool _isSafeExternalUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (uri.host.isEmpty) return false;
    return true;
  }
}

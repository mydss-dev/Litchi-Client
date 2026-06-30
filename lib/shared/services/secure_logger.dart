import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_paths.dart';

abstract final class SecureLogRedactor {
  static const int maxLogTextLength = 800;

  static final RegExp _dialEndpoint = RegExp(
    r'((?:dial(?:ing)?(?:\s+(?:tcp|udp))?|connect(?:ing)?\s+to)\s+)'
    r'(?:\[[0-9a-f:]+\]|(?:\d{1,3}\.){3}\d{1,3}|[a-z0-9.-]+):\d{1,5}',
    caseSensitive: false,
  );

  static final List<RegExp> _patterns = [
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    RegExp(r'(?<=Authorization:\s*)[^\s,;]+', caseSensitive: false),
    RegExp(
      r'''([?&](token|auth_data|password|passwd|key|uuid)=)[^&\s"'<>]+''',
      caseSensitive: false,
    ),
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    RegExp(
      r'''(vmess|vless|trojan|ss|hysteria2|hy2|tuic|juicity)://[^\s"'<>]+''',
    ),
    RegExp(
      r'''(https?://[^\s"'<>]*?(token|sub|subscribe|subscription|auth|secret)[^\s"'<>]*)''',
      caseSensitive: false,
    ),
    RegExp(
      r'''([?&](token|auth_token|access_token|password|passwd|secret|key|api_key|apikey|sign|signature)=)[^&\s"'<>]+''',
      caseSensitive: false,
    ),
    RegExp(
      r'''("?(password|uuid|server|server_name|public_key|short_id)"?\s*[:=]\s*)["']?[^"',}\s]+["']?''',
      caseSensitive: false,
    ),
  ];

  static String redact(Object? value) {
    var text = value?.toString() ?? '';
    text = text.replaceAllMapped(
      _dialEndpoint,
      (match) => '${match.group(1)}[ENDPOINT]',
    );
    for (final pattern in _patterns) {
      text = text.replaceAllMapped(pattern, (match) {
        final prefix = match.groupCount >= 2 ? match.group(1) : null;
        if (prefix != null && prefix.contains(RegExp(r'[:=]'))) {
          return '$prefix[REDACTED]';
        }
        return '[REDACTED]';
      });
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > maxLogTextLength) {
      text = '${text.substring(0, maxLogTextLength)}… [truncated]';
    }
    return text;
  }
}

abstract final class SecureLogger {
  /// Max size of the on-disk diagnostic log before it is rotated (256 KB).
  static const int _maxLogBytes = 256 * 1024;

  /// Debug-only console log. No-op in release.
  static void debug(String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint(_format(message, error));
  }

  /// Records a warning that must survive release builds. The line is redacted,
  /// echoed to the console in debug mode, and appended (best-effort, size-
  /// bounded) to a local diagnostic log so swallowed failures stay diagnosable.
  static void warn(String message, [Object? error]) {
    final line = _format(message, error);
    if (kDebugMode) debugPrint(line);
    unawaited(_append(line));
  }

  static String _format(String message, Object? error) {
    final ts = DateTime.now().toLocal().toString();
    final suffix = error == null ? '' : ': ${SecureLogRedactor.redact(error)}';
    return '[$ts] ${SecureLogRedactor.redact(message)}$suffix';
  }

  static Future<void> _append(String line) async {
    try {
      final dir = Directory(AppPaths.dataDirectory);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}diagnostic.log');
      if (file.existsSync() && file.lengthSync() > _maxLogBytes) {
        // Rotate by truncation — keep the log self-limiting without a scheduler.
        file.writeAsStringSync('', flush: false);
      }
      file.writeAsStringSync('$line\n', mode: FileMode.append, flush: false);
    } catch (_) {
      // intentional: logging must never throw into the caller's path.
    }
  }
}

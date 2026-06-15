import 'package:flutter/foundation.dart';

abstract final class SecureLogRedactor {
  static final List<RegExp> _patterns = [
    RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    RegExp(r'(?<=Authorization:\s*)[^\s,;]+', caseSensitive: false),
    RegExp(
      r'''([?&](token|auth_data|password|passwd|key|uuid)=)[^&\s"'<>]+''',
      caseSensitive: false,
    ),
    RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
    RegExp(r'''(vmess|vless|trojan|ss|hysteria2|hy2)://[^\s"'<>]+'''),
    RegExp(
      r'''(https?://[^\s"'<>]*?(token|sub|subscribe)[^\s"'<>]*)''',
      caseSensitive: false,
    ),
    RegExp(
      r'''("?(password|uuid|server|server_name|public_key|short_id)"?\s*[:=]\s*)["']?[^"',}\s]+["']?''',
      caseSensitive: false,
    ),
  ];

  static String redact(Object? value) {
    var text = value?.toString() ?? '';
    for (final pattern in _patterns) {
      text = text.replaceAllMapped(pattern, (match) {
        final prefix = match.groupCount >= 2 ? match.group(1) : null;
        if (prefix != null && prefix.contains(RegExp(r'[:=]'))) {
          return '$prefix[REDACTED]';
        }
        return '[REDACTED]';
      });
    }
    return text;
  }
}

abstract final class SecureLogger {
  static void debug(String message, [Object? error]) {
    if (!kDebugMode) return;
    final suffix = error == null ? '' : ': ${SecureLogRedactor.redact(error)}';
    debugPrint('${SecureLogRedactor.redact(message)}$suffix');
  }
}

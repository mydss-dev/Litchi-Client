/// Converts the lightweight HTML returned by compatible panels into the plain
/// feature rows rendered by the shop. This intentionally avoids a WebView or
/// HTML renderer: plan descriptions are display-only text in Litchi V3.
abstract final class PlanDescriptionParser {
  static List<String> toFeatures(String raw) {
    if (raw.trim().isEmpty) return const [];

    var text = raw
        .replaceAll(RegExp(r'<!--[\s\S]*?-->', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'<script\b[^>]*>[\s\S]*?</script\s*>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style\b[^>]*>[\s\S]*?</style\s*>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</(?:p|div|li|ul|ol|h[1-6]|tr|table)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<hr\b[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<li(?:\s[^>]*)?>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'</(?:td|th)\s*>', caseSensitive: false), ' · ')
        .replaceAll(RegExp(r'<[^>]+>'), '');

    text = _decodeEntities(text)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\t\u000B\u000C]+'), ' ')
        .replaceAll(RegExp(r'[ ]{2,}'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{2,}'), '\n');

    return text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'(?:\s*·\s*)+$'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String _decodeEntities(String input) {
    const named = <String, String>{
      'nbsp': ' ',
      'ensp': ' ',
      'emsp': ' ',
      'amp': '&',
      'lt': '<',
      'gt': '>',
      'quot': '"',
      'apos': "'",
    };

    return input.replaceAllMapped(
      RegExp(r'&(#(?:x[0-9a-fA-F]+|\d+)|[A-Za-z]+);'),
      (match) {
        final token = match.group(1)!;
        if (!token.startsWith('#')) return named[token.toLowerCase()] ?? match.group(0)!;

        final hex = token.length > 2 && token[1].toLowerCase() == 'x';
        final digits = hex ? token.substring(2) : token.substring(1);
        final value = int.tryParse(digits, radix: hex ? 16 : 10);
        if (value == null || value < 0 || value > 0x10ffff) {
          return match.group(0)!;
        }
        if (value >= 0xd800 && value <= 0xdfff) return match.group(0)!;
        return String.fromCharCode(value);
      },
    );
  }
}

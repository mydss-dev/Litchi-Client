/// Converts a panel plan description to the plain-text rows used by V3 cards
/// and the complete details sheet. This is intentionally a text conversion,
/// not an HTML renderer: backend markup is never executed or injected into UI.
abstract final class PlanDescriptionParser {
  static final RegExp _tags = RegExp(
    r'<(/?)([A-Za-z][A-Za-z0-9:-]*)\b[^>]*>',
    caseSensitive: false,
  );
  static final RegExp _entities = RegExp(
    r'&(#(?:[xX][0-9A-Fa-f]+|[0-9]+)|[A-Za-z][A-Za-z0-9]+);',
  );
  static const Set<String> _knownTags = {
    'a', 'article', 'b', 'blockquote', 'br', 'code', 'dd', 'del',
    'div', 'dl', 'dt', 'em', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'hr', 'i', 'img', 'li', 'ol', 'p', 'pre', 's', 'section',
    'small', 'span', 'strong', 'sub', 'sup', 'table', 'tbody',
    'td', 'th', 'thead', 'tr', 'u', 'ul',
  };
  static const Set<String> _blocks = {
    'article', 'blockquote', 'dd', 'div', 'dl', 'dt',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'hr', 'li', 'ol',
    'p', 'pre', 'section', 'table', 'tbody', 'thead', 'tr', 'ul',
  };
  static const Map<String, String> _named = {
    'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'",
    'nbsp': ' ', 'ndash': '–', 'mdash': '—', 'bull': '•',
    'hellip': '…', 'middot': '·', 'times': '×', 'copy': '©',
    'reg': '®', 'trade': '™', 'euro': '€', 'yen': '¥',
    'pound': '£', 'cent': '¢', 'laquo': '«', 'raquo': '»',
  };

  static List<String> parse(String source) {
    if (source.trim().isEmpty) return const [];
    var raw = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    raw = raw.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    for (final element in ['script', 'style']) {
      raw = raw.replaceAll(
        RegExp(
          r'<\s*' + element + r'\b[^>]*>.*?<\s*/\s*' + element + r'\s*>',
          caseSensitive: false,
          dotAll: true,
        ),
        '',
      );
    }

    final text = StringBuffer();
    var atLineStart = true;
    var orderedItem = -1;

    void append(String value) {
      if (value.isEmpty) return;
      text.write(value);
      atLineStart = value.endsWith('\n');
    }

    void lineBreak() {
      if (!atLineStart) append('\n');
    }

    var cursor = 0;
    for (final tag in _tags.allMatches(raw)) {
      append(_decode(raw.substring(cursor, tag.start)));
      cursor = tag.end;
      final name = tag.group(2)!.toLowerCase();
      if (!_knownTags.contains(name)) {
        // Unknown or custom markup must not silently lose its source text.
        append(tag.group(0)!);
        continue;
      }
      final closing = tag.group(1) == '/';
      if (name == 'br' || name == 'hr') {
        lineBreak();
      } else if (name == 'ol') {
        lineBreak();
        orderedItem = closing ? -1 : 0;
      } else if (name == 'li') {
        lineBreak();
        if (!closing) {
          append(orderedItem >= 0 ? '${++orderedItem}. ' : '• ');
        }
      } else if (name == 'td' || name == 'th') {
        if (!closing && !atLineStart) append(' · ');
      } else if (_blocks.contains(name)) {
        lineBreak();
      }
    }
    append(_decode(raw.substring(cursor)));
    return text
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String _decode(String text) => text.replaceAllMapped(_entities, (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#')) {
      final hex = entity.length > 2 &&
          (entity[1] == 'x' || entity[1] == 'X');
      final value = int.tryParse(
        entity.substring(hex ? 2 : 1),
        radix: hex ? 16 : 10,
      );
      if (value == null || value <= 0 || value > 0x10FFFF ||
          (value >= 0xD800 && value <= 0xDFFF)) {
        return match.group(0)!;
      }
      return String.fromCharCode(value);
    }
    return _named[entity.toLowerCase()] ?? match.group(0)!;
  });
}

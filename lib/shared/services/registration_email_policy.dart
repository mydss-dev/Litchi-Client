/// Client-side feedback for the registration suffix whitelist supplied by
/// /guest/comm/config. The panel is always authoritative.
abstract final class RegistrationEmailPolicy {
  /// An ordinary rule such as `gmail.com` (or `@gmail.com`) allows ONLY that
  /// domain, matching the panel's explicit email-domain choices. Subdomains
  /// are permitted only when the backend explicitly configures `*.example.org`.
  static bool allows(String email, List<String> allowedSuffixes) {
    if (allowedSuffixes.isEmpty) return true;

    final candidate = email.trim().toLowerCase();
    final at = candidate.indexOf('@');
    if (at <= 0 || at != candidate.lastIndexOf('@') ||
        at == candidate.length - 1) {
      return false;
    }
    final domain = candidate.substring(at + 1);
    if (domain.contains(RegExp(r'\s')) || domain.startsWith('.') ||
        domain.endsWith('.') || domain.contains('..')) {
      return false;
    }

    for (final item in allowedSuffixes) {
      final rule = item.trim().toLowerCase();
      if (rule.isEmpty) continue;
      if (rule.startsWith('*.')) {
        final base = rule.substring(2);
        if (base.isNotEmpty && domain.endsWith('.$base')) return true;
        continue;
      }
      if (rule.startsWith('.')) {
        // Explicit TLD-style wildcard, e.g. `.edu` for university.edu.
        if (domain.endsWith(rule) && domain.length > rule.length) return true;
        continue;
      }
      final exact = rule.startsWith('@') ? rule.substring(1) : rule;
      if (exact.isNotEmpty && domain == exact) return true;
    }
    return false;
  }

  /// Domain choices suitable for the prefix + dropdown UI. Wildcard entries
  /// must remain editable as full addresses, not offered as literal domains.
  static List<String> getSelectableDomains(List<String> suffixes) => suffixes
      .map((entry) => entry.trim().toLowerCase())
      .where((entry) => entry.isNotEmpty && !entry.startsWith('.') &&
          !entry.startsWith('*.'))
      .map((entry) => entry.startsWith('@') ? entry.substring(1) : entry)
      .where((entry) => entry.isNotEmpty)
      .toSet()
      .toList();
}

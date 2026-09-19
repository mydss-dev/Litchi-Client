/// Client-side feedback for the registration suffix whitelist supplied by
/// /guest/comm/config. The server always makes the final registration decision.
abstract final class RegistrationEmailPolicy {
  static bool allows(String email, List<String> allowedSuffixes) {
    if (allowedSuffixes.isEmpty) return true;

    final candidate = email.trim().toLowerCase();
    final at = candidate.indexOf('@');
    if (at <= 0 || at != candidate.lastIndexOf('@') ||
        at == candidate.length - 1) {
      return false;
    }
    final domain = candidate.substring(at + 1);

    for (final item in allowedSuffixes) {
      final rule = item.trim().toLowerCase();
      if (rule.isEmpty) continue;
      // A leading @ explicitly limits the rule to this exact email domain.
      if (rule.startsWith('@')) {
        if (domain == rule.substring(1)) return true;
        continue;
      }
      if (rule.startsWith('*.')) {
        final base = rule.substring(2);
        if (base.isNotEmpty && domain.endsWith('.$base')) return true;
        continue;
      }
      final suffix = rule.startsWith('.') ? rule.substring(1) : rule;
      // Match complete DNS labels only: evilgmail.com is not gmail.com.
      if (suffix.isNotEmpty &&
          (domain == suffix || domain.endsWith('.$suffix'))) {
        return true;
      }
    }
    return false;
  }
}

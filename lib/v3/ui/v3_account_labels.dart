import 'package:flutter/widgets.dart';

import 'v3_locale_copy.dart';

/// Only substitute UI copy when the account identity has not loaded. Real
/// backend values are displayed unchanged, including non-Latin account names.
String v3AccountDisplayName(BuildContext context, String? name) {
  if (name != null && name.trim().isNotEmpty) return name.trim();
  return v3Copy(
    context,
    zh: '资料待同步',
    en: 'Details pending',
    tw: '資料待同步',
  );
}

String v3AccountEmailLabel(BuildContext context, String? email) {
  if (email != null && email.trim().isNotEmpty) return email.trim();
  return v3Copy(
    context,
    zh: '邮箱待同步',
    en: 'Email pending',
    tw: '電子郵件待同步',
  );
}

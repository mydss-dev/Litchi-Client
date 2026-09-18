import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';

/// Translate V3-specific copy missing from the older ARB catalogs.
/// Dynamic backend data (plan titles, node names, notices) is not UI copy and
/// must remain unchanged. The locale comes from the same persisted app setting
/// as the existing ARB-generated strings.
String v3Copy(BuildContext context, {
  required String zh,
  required String en,
  required String tw,
}) {
  final locale = (Localizations.of<AppLocalizations>(
    context, AppLocalizations,
  ) ?? AppLocalizationsZh()).localeName;
  if (locale.startsWith('en')) return en;
  if (locale.toLowerCase().contains('tw')) return tw;
  return zh;
}

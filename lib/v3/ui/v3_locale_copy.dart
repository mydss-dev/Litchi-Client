import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/services/app_error_message_service.dart';

/// The application supplies localization delegates. Some standalone widget
/// previews omit them, so those previews use the same Simplified Chinese
/// fallback instead of each component constructing its own.
AppLocalizations v3Localizations(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    AppLocalizationsZh();

/// Translate V3-specific copy missing from the older ARB catalogs.
/// Dynamic backend data (plan titles, node names, notices) is not UI copy and
/// must remain unchanged. The locale comes from the same persisted app setting
/// as the existing ARB-generated strings.
String v3Copy(BuildContext context, {
  required String zh,
  required String en,
  required String tw,
}) {
  final locale = v3Localizations(context).localeName;
  if (locale.startsWith('en')) return en;
  if (locale.toLowerCase().contains('tw')) return tw;
  return zh;
}

/// Normalize any thrown error into the shared user-facing message: the same
/// mapping the rest of the app uses, so a V3 surface can never show a raw
/// exception string (round-3 audit N13).
String v3UserFacingError(BuildContext context, Object error) =>
    AppErrorMessageService.userFacing(error, v3Localizations(context));

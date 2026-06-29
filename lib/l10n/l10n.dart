import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'app_locale_preference.dart';
export 'generated/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

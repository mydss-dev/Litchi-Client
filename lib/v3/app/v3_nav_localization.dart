import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import 'v3_nav.dart';

/// Use the current app locale for navigation copy without changing the stable
/// route definitions or their Chinese identifiers used by existing tests.
extension V3LocalizedNavigation on V3NavItem {
  String localizedLabel(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsZh();
    return switch (page) {
      AppPage.dashboard => l.startConnection,
      AppPage.nodes => l.nodes,
      AppPage.shop => l.plans,
      AppPage.account => l.account,
      AppPage.more => l.localeName.startsWith('en') ? 'More' : '更多',
      AppPage.orders => l.orders,
      AppPage.giftCard => l.giftCardTitle,
      AppPage.traffic => l.usage,
      AppPage.invite => l.invite,
      AppPage.tickets => l.tickets,
      AppPage.settings => l.settings,
    };
  }
}

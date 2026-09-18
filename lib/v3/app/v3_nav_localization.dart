import 'package:flutter/widgets.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import 'v3_nav.dart';

/// Localize a nav item's label using the current app locale.
extension V3LocalizedNavigation on V3NavItem {
  String localizedLabel(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsZh();
    return switch (page) {
      AppPage.dashboard => l.connection,
      AppPage.nodes => l.nodes,
      AppPage.shop => l.plans,
      AppPage.account => l.account,
      AppPage.more => l.more,
      AppPage.traffic => l.trafficUsage,
      AppPage.invite => l.inviteFriends,
      AppPage.tickets => l.support,
      AppPage.settings => l.clientSettings,
      AppPage.orders => l.orders,
      AppPage.giftCard => l.giftCardRedemption,
      _ => '',
    };
  }
}

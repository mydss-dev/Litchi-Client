import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../app/v3_nav.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_sheet.dart';

/// The compact overflow tab. Its labels use the same app locale as settings;
/// the nav model still owns order and visibility, not presentation language.
class V3MorePage extends StatelessWidget {
  const V3MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizationsZh();
    final english = l.localeName.startsWith('en');
    final traditional = l.localeName.toLowerCase().contains('tw');
    final items = enabledNavItems(kMobileMore);
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: english ? 'Tools & services' : traditional ? '服務與工具' : '服务与工具',
            title: english ? 'More services' : traditional ? '更多服務' : '更多服务',
            description: english
                ? 'Features outside the account and primary tabs live here.'
                : traditional
                    ? '帳戶及主要分頁以外的功能都在這裡。'
                    : '不属于账户，也不常驻底栏的功能都在这里。',
          ),
          const SizedBox(height: 22),
          if (items.isEmpty)
            V3Panel(
              child: Text(
                english ? 'No additional features are enabled on this server.'
                    : traditional ? '目前伺服器沒有提供其他功能。' : '当前服务端没有提供其他功能。',
                style: TextStyle(
                  color: V3Palette.of(context).inkMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            V3NavPanel(
              title: english ? 'All features' : traditional ? '全部功能' : '全部功能',
              children: [
                for (final item in items)
                  V3NavRow(
                    key: moreRowKey(item.page),
                    icon: item.icon,
                    label: item.localizedLabel(context),
                    selected: controller.page == item.page,
                    onTap: () => openV3Page(context, item.page),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

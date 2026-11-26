import 'package:material_ui/material_ui.dart';

import '../../app/app_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/theme/app_icons.dart';
import '../app/v3_nav.dart';
import '../ui/v3_components.dart';
import '../ui/v3_empty_state.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_mobile_components.dart';
import '../ui/v3_sheet.dart';

/// Legacy 更多 route, kept only so an old deep link still resolves. The tab is
/// retired and the account hub owns every destination here; site notices and
/// redemption moved onto 我的 as well. Nothing in the compact shell links here.
///
/// The labels follow the app locale; the nav model still owns order and
/// visibility, not presentation language. Rows use the shared mobile list row,
/// so this page, the account hub and settings keep one row rhythm.
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3MobileDesign.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PrimaryPageHeader(
            title: english ? 'More' : '更多',
            subtitle: english
                ? 'Other account and service tools'
                : traditional
                    ? '存取其他帳戶與服務功能'
                    : '访问其他账户与服务功能',
          ),
          const SizedBox(height: V3MobileDesign.sectionGap),
          if (items.isEmpty)
            // Shared empty-state voice (icon tile, one muted line).
            V3EmptyState(
              icon: AppIcons.grid,
              title: english
                  ? 'No extra services on this server.'
                  : traditional
                      ? '暫無更多服務'
                      : '暂无更多服务',
              subtitle: english
                  ? 'No additional features are enabled on this server.'
                  : traditional
                      ? '目前伺服器沒有提供其他功能。'
                      : '当前服务端没有提供其他功能。',
            )
          else
            V3MobileGroupCard(
              children: [
                for (final item in items.where((item) =>
                    item.page != AppPage.giftCard ||
                    controller.hasConfirmedNoPlan))
                  V3MobileListRow(
                    key: moreRowKey(item.page),
                    icon: item.icon,
                    label: item.localizedLabel(context),
                    onTap: () => openV3Page(context, item.page),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

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
    final p = V3Palette.of(context);
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            title: english ? 'More services' : traditional ? '更多服務' : '更多服务',
          ),
          const SizedBox(height: 18),
          if (items.isEmpty)
            V3Panel(
              child: Text(
                english ? 'No additional features are enabled on this server.'
                    : traditional ? '目前伺服器沒有提供其他功能。' : '当前服务端没有提供其他功能。',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            LayoutBuilder(builder: (context, constraints) {
              // On a phone the destinations stay one list to scan. On a wide
              // window the full-width card hugs the top of an otherwise empty
              // page, so the same rows tile two-across and use the canvas
              // (the Windows-Settings home pattern).
              if (constraints.maxWidth < V3Layout.paneCompact) {
                return V3NavPanel(
                  title:
                      english ? 'All features' : traditional ? '全部功能' : '全部功能',
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
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final item in items)
                    Container(
                      width: (constraints.maxWidth - 12) / 2,
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(V3Radius.panel),
                        border: Border.all(color: p.hairline),
                        boxShadow: p.shadows,
                      ),
                      child: V3NavRow(
                        key: moreRowKey(item.page),
                        icon: item.icon,
                        label: item.localizedLabel(context),
                        selected: controller.page == item.page,
                        onTap: () => openV3Page(context, item.page),
                      ),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

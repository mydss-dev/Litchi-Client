import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../app/v3_nav.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

/// The compact overflow tab.
///
/// Wide layouts reach these four pages from the rail, so this page only ever
/// appears on narrow ones — but it is built from the same nav model either way,
/// so a page that gains or loses a rail entry stays in step here.
class V3MorePage extends StatelessWidget {
  const V3MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final items = enabledNavItems(kMobileMore);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V3PageHeader(
            kicker: '更多',
            title: '更多服务',
            description: '不属于账户，也不常驻底栏的功能都在这里。',
          ),
          const SizedBox(height: 22),
          if (items.isEmpty)
            V3Panel(
              child: Text(
                '当前服务端没有提供其他功能。',
                style: TextStyle(
                  color: V3Palette.of(context).inkMuted,
                  fontSize: 12,
                ),
              ),
            )
          else
            V3NavPanel(
              title: '全部功能',
              children: [
                for (final item in items)
                  V3NavRow(
                    key: moreRowKey(item.page),
                    icon: item.icon,
                    label: item.label,
                    selected: controller.page == item.page,
                    onTap: () => controller.goToPage(item.page),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

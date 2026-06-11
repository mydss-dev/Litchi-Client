import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_text_styles.dart';
import 'brand_logo.dart';

/// Left navigation rail (§8). Fixed 160px wide.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const _items = <_MenuItem>[
    _MenuItem(AppPage.dashboard, '首页', LucideIcons.home),
    _MenuItem(AppPage.nodes, '节点', LucideIcons.globe),
    _MenuItem(AppPage.traffic, '统计', LucideIcons.barChart3),
    _MenuItem.separator(),
    _MenuItem(AppPage.shop, '商城', LucideIcons.shoppingBag),
    _MenuItem(AppPage.orders, '订单', LucideIcons.clipboardList),
    _MenuItem.separator(),
    _MenuItem(AppPage.account, '账户', LucideIcons.user),
    _MenuItem(AppPage.invite, '邀请', LucideIcons.gift),
    _MenuItem(AppPage.tickets, '工单', LucideIcons.messageSquare),
    _MenuItem.separator(),
    _MenuItem(AppPage.settings, '设置', LucideIcons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final controller = AppScope.of(context);

    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: c.sidebarBg,
        border: Border(right: BorderSide(color: c.sidebarBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandArea(),
          const SizedBox(height: 22),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final item in _items)
                    if (item.separator)
                      _SidebarDivider(color: c.softBorder)
                    else ...[
                      _SidebarMenuItem(
                        item: item,
                        selected: controller.page == item.page,
                        onTap: () => controller.goToPage(item.page!),
                      ),
                      const SizedBox(height: 6),
                    ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _PlanStatusCard(),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.page, this.label, this.icon) : separator = false;
  const _MenuItem.separator()
    : page = null,
      label = '',
      icon = LucideIcons.minus,
      separator = true;

  final AppPage? page;
  final String label;
  final IconData icon;
  final bool separator;
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider({required this.color});

  final Color color;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Divider(height: 1, thickness: 1, color: color),
    );
  }
}

class _BrandArea extends StatelessWidget {
  const _BrandArea();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandLogo(size: 40, radius: 12),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Litchi',
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Network Client',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: c.textMuted,
                  fontFamilyFallback: AppTextStyles.fontFamilyFallback,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarMenuItem extends StatefulWidget {
  const _SidebarMenuItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _MenuItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarMenuItem> createState() => _SidebarMenuItemState();
}

class _SidebarMenuItemState extends State<_SidebarMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Color bg = Colors.transparent;
    Color iconColor = c.iconDefault;
    Color textColor = c.textSecondary;

    if (widget.selected) {
      bg = c.primarySoft;
      iconColor = c.primary;
      textColor = c.primary;
    } else if (_hover) {
      bg = c.surfaceMuted;
      iconColor = c.primary;
      textColor = c.textPrimary;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 42,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.selected ? c.primary : Colors.transparent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Icon(widget.item.icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: AppTextStyles.menu.copyWith(color: textColor),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final traffic = ctrl.traffic;
    final ratio = (traffic.usedGb / traffic.totalGb).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  user.plan,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
              Container(
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Active',
                  style: AppTextStyles.badge.copyWith(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${traffic.usedGb.toStringAsFixed(1)} GB / ${traffic.totalGb.toStringAsFixed(0)} GB',
            style: AppTextStyles.caption.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 7, color: c.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: c.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '剩余 ${traffic.remainGb.toStringAsFixed(0)} GB · ${user.plan}',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

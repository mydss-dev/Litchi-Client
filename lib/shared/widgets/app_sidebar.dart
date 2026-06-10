import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';
import 'brand_logo.dart';

/// Left navigation rail (§8). Fixed 160px wide.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const _items = <_MenuItem>[
    _MenuItem(AppPage.dashboard, '首页', LucideIcons.home),
    _MenuItem(AppPage.nodes, '节点', LucideIcons.globe),
    _MenuItem(AppPage.shop, '商城', LucideIcons.shoppingBag),
    _MenuItem(AppPage.traffic, '统计', LucideIcons.barChart3),
    _MenuItem(AppPage.invite, '邀请', LucideIcons.gift),
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
          const SizedBox(height: 28),
          for (final item in _items) ...[
            _SidebarMenuItem(
              item: item,
              selected: controller.page == item.page,
              onTap: () => controller.goToPage(item.page),
            ),
            const SizedBox(height: 10),
          ],
          const Spacer(),
          const _UserCard(),
        ],
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.page, this.label, this.icon);
  final AppPage page;
  final String label;
  final IconData icon;
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
    Border? border;

    if (widget.selected) {
      bg = c.primarySoft;
      iconColor = c.primary;
      textColor = c.primary;
      border = Border.all(color: c.primary);
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
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: border,
          ),
          child: Row(
            children: [
              Icon(widget.item.icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.item.label,
                  style: AppTextStyles.menu.copyWith(color: textColor),
                ),
              ),
              if (widget.selected)
                Icon(LucideIcons.chevronRight, size: 14, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  const _UserCard();

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _sizeFactor;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sizeFactor = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  // Deterministic color per username.
  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDC2626),
      Color(0xFF0891B2),
    ];
    final hash = name.isEmpty ? 0 : name.codeUnits.reduce((a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final avatarColor = _avatarColor(user.name);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Expandable panel (slides up from above the card) ──────────────
        SizeTransition(
          sizeFactor: _sizeFactor,
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // Reserve space for: sidebar padding(18+16) + brand(56) +
                  // gap(28) + 6 menu items(360) + user card row(54) +
                  // popup bottom margin(8) + small buffer(8).
                  maxHeight: (MediaQuery.of(context).size.height - 548).clamp(
                    120.0,
                    500.0,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: c.softBorder),
                      boxShadow: AppShadows.soft(c),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan row
                        Row(
                          children: [
                            Icon(LucideIcons.crown, size: 13, color: c.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                user.plan,
                                style: AppTextStyles.bodyStrong.copyWith(
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: c.premiumBadgeBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '到期 ${user.expiry}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: c.premiumBadgeText,
                                  fontFamilyFallback:
                                      AppTextStyles.fontFamilyFallback,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // My Account
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              _toggle();
                              ctrl.goToPage(AppPage.account);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.user,
                                    size: 13,
                                    color: c.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '我的账户',
                                  style: AppTextStyles.body.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // My Orders
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              _toggle();
                              ctrl.goToPage(AppPage.orders);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.clipboardList,
                                    size: 13,
                                    color: c.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '我的订单',
                                  style: AppTextStyles.body.copyWith(
                                    color: c.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(height: 1, color: c.softBorder),
                        const SizedBox(height: 8),
                        // Logout button
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              _toggle();
                              ctrl.logout();
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: c.danger.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    LucideIcons.logOut,
                                    size: 13,
                                    color: c.danger,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '退出登录',
                                  style: AppTextStyles.body.copyWith(
                                    color: c.danger,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── User card row (always visible) ────────────────────────────────
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 54,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _expanded ? c.primarySoft : c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.user),
                border: _expanded
                    ? Border.all(color: c.primary.withValues(alpha: 0.35))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      user.avatarLetter,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.cardTitle.copyWith(
                            color: _expanded ? c.primary : c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.plan,
                          style: TextStyle(
                            fontSize: 10,
                            color: _expanded ? c.primary : c.textMuted,
                            fontFamilyFallback:
                                AppTextStyles.fontFamilyFallback,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5).animate(_sizeFactor),
                    child: Icon(
                      LucideIcons.chevronUp,
                      size: 13,
                      color: _expanded ? c.primary : c.iconMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

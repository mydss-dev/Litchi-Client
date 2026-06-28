import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../../config/mobile_layout.dart';
import '../../shared/models/api_models.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/services/secure_logger.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../mobile/mobile_page_header.dart';

/// Account / Profile — a single responsive page.
///
/// Two-layout merge. Wide keeps the desktop account view (info card, shortcut
/// grid, login records — loaded via `_load` on first dependency change). Compact
/// keeps the mobile profile view (pull-to-refresh, profile header, menu section,
/// settings/password/logout bottom sheets). There are no field, method, or
/// sub-widget name collisions between the two, so this is a straight union: the
/// desktop state (`_load`/`_copy` + login data) and the mobile state (`_updating`
/// + sheet handlers) coexist untouched. Split on window width.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  // Wide-branch state (login info loaded on demand).
  bool _loading = true;
  String? _error;
  RemoteUser? _user;
  List<RemoteLoginLog> _loginLogs = [];
  bool _initialized = false;

  // Compact-branch state.
  bool _updating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppScope.of(context).api;
      final user = await api.getUserInfo();
      List<RemoteLoginLog> logs = [];
      try {
        logs = await api.getLoginLogs();
      } catch (e) {
        SecureLogger.debug('get login logs failed', e);
      }
      if (!mounted) return;
      setState(() {
        _user = user;
        _loginLogs = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('ApiException: ', '');
        _loading = false;
      });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppToast.show(context, '$label 已复制', type: AppToastType.success);
  }

  // ── Compact-branch handlers (settings / password / logout sheets) ──────
  Future<void> _updateSettings({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updating) return;
    final ctrl = AppScope.of(context);
    _updating = true;
    final error = await ctrl.updateUserSettings(
      remindExpire: remindExpire ?? ctrl.user.remindExpire,
      remindTraffic: remindTraffic ?? ctrl.user.remindTraffic,
      autoRenewal: autoRenewal ?? ctrl.user.autoRenewal,
    );
    if (!mounted) return;
    _updating = false;
    AppToast.show(
      context,
      error ?? '设置已更新',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  void _showAccountSheet() {
    final ctrl = AppScope.of(context);
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) => _AccountManageSheet(
          remindExpire: ctrl.user.remindExpire,
          remindTraffic: ctrl.user.remindTraffic,
          autoRenewal: ctrl.user.autoRenewal,
          onExpireChanged: (value) => _updateSettings(remindExpire: value),
          onTrafficChanged: (value) => _updateSettings(remindTraffic: value),
          onAutoRenewalChanged: (value) => _updateSettings(autoRenewal: value),
          onChangePassword: () {
            Navigator.of(context).pop();
            _showChangePasswordSheet();
          },
          onLogout: () {
            Navigator.of(context).pop();
            _confirmLogout();
          },
        ),
      ),
    );
  }

  Future<void> _handlePullRefresh() async {
    final ctrl = AppScope.of(context);
    await ctrl.refreshData();
    if (!mounted || ctrl.dataLoadError != null) return;
    AppToast.show(context, '已刷新', type: AppToastType.success);
  }

  void _showChangePasswordSheet() {
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => const _LogoutSheet(),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.of(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    return context.isCompact ? _buildCompact(context) : _buildWide(context);
  }

  // ── Wide (sidebar) layout ──────────────────────────────────────────────
  Widget _buildWide(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: PageHeader(title: '我的账户', subtitle: '查看账户信息与订阅详情'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const PageLoadingCard()
          else if (_error != null)
            PageErrorCard(message: _error!, onRetry: _load)
          else
            _AccountContent(
              user: _user!,
              loginLogs: _loginLogs,
              onCopy: _copy,
              onNavigate: AppScope.of(context).goToPage,
            ),
        ],
      ),
    );
  }

  // ── Compact (bottom-nav) layout ────────────────────────────────────────
  Widget _buildCompact(BuildContext context) {
    final ctrl = AppScope.of(context);
    final user = ctrl.user;
    final summaryType = MobileLayout.profileSummaryCard;

    return RefreshIndicator(
      onRefresh: _handlePullRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          const MobilePageHeader(title: '我的', subtitle: '账号信息与套餐状态'),
          const SizedBox(height: 14),
          _ProfileHeader(
            userName: user.name,
            plan: user.plan,
            expiry: user.expiry,
            avatar: user.avatarLetter,
            hidePlan: _isPlanSummary(summaryType),
            hideExpiry: _isExpireSummary(summaryType),
            onManage: _showAccountSheet,
          ),
          const SizedBox(height: 12),
          _ProfileSummaryCard(type: summaryType, ctrl: ctrl),
          const SizedBox(height: 14),
          _ProfileMenuSection(ctrl: ctrl),
        ],
      ),
    );
  }
}

// ── Wide-layout widgets (original desktop AccountPage, verbatim) ──────────

class _AccountContent extends StatelessWidget {
  const _AccountContent({
    required this.user,
    required this.loginLogs,
    required this.onCopy,
    required this.onNavigate,
  });

  final RemoteUser user;
  final List<RemoteLoginLog> loginLogs;
  final void Function(String text, String label) onCopy;
  final ValueChanged<AppPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = AppConfig.avatarUrl.trim();
    final fallbackLetter = user.email.isNotEmpty ? user.email[0].toUpperCase() : 'L';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Avatar(
              url: avatarUrl,
              fallbackLetter: fallbackLetter,
              size: 64,
            ),
          ),
        ),
        _AccountInfoCard(user: user, onCopy: onCopy),
        const SizedBox(height: 14),
        _AccountShortcutGrid(onNavigate: onNavigate),
        const SizedBox(height: 14),
        _LoginRecordsCard(logs: loginLogs),
      ],
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({required this.user, required this.onCopy});

  final RemoteUser user;
  final void Function(String, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (statusLabel, statusColor) = switch (user.subscribeStatus) {
      1 => ('已到期', c.danger),
      2 => ('已封禁', c.warning),
      _ => ('正常', c.success),
    };

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.user, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Text(
                '账户信息',
                style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: '邮箱',
            value: user.email,
            trailing: _CopyButton(onTap: () => onCopy(user.email, '邮箱')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  '账户状态',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ),
              AppBadge(
                text: statusLabel,
                background: statusColor.withValues(alpha: 0.12),
                textColor: statusColor,
                fontSize: 11,
                height: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(label: '到期时间', value: user.expiryDisplay),
        ],
      ),
    );
  }
}

class _AccountShortcutGrid extends StatelessWidget {
  const _AccountShortcutGrid({required this.onNavigate});

  final ValueChanged<AppPage> onNavigate;

  static const _items = [
    _AccountShortcut(
      page: AppPage.wallet,
      icon: LucideIcons.walletCards,
      title: '我的钱包',
      subtitle: '余额与充值',
    ),
    _AccountShortcut(
      page: AppPage.orders,
      icon: LucideIcons.clipboardList,
      title: '订单记录',
      subtitle: '购买与支付',
    ),
    _AccountShortcut(
      page: AppPage.traffic,
      icon: LucideIcons.chartNoAxesColumnIncreasing,
      title: '流量统计',
      subtitle: '使用记录',
    ),
    _AccountShortcut(
      page: AppPage.tickets,
      icon: LucideIcons.messageSquare,
      title: '工单支持',
      subtitle: '联系售后',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 88,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _AccountShortcutTile(
              item: item,
              onTap: () => onNavigate(item.page),
            );
          },
        );
      },
    );
  }
}

class _AccountShortcut {
  const _AccountShortcut({
    required this.page,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final AppPage page;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _AccountShortcutTile extends StatefulWidget {
  const _AccountShortcutTile({required this.item, required this.onTap});

  final _AccountShortcut item;
  final VoidCallback onTap;

  @override
  State<_AccountShortcutTile> createState() => _AccountShortcutTileState();
}

class _AccountShortcutTileState extends State<_AccountShortcutTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover ? c.primarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: _hover ? c.primary : c.softBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(widget.item.icon, size: 18, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: c.iconMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(color: c.textPrimary),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(LucideIcons.copy, size: 13, color: c.iconDefault),
        ),
      ),
    );
  }
}

class _LoginRecordsCard extends StatelessWidget {
  const _LoginRecordsCard({required this.logs});

  final List<RemoteLoginLog> logs;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.shieldCheck, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Text(
                '登录记录',
                style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '暂无登录记录',
                style: AppTextStyles.body.copyWith(color: c.textMuted),
              ),
            )
          else
            for (int i = 0; i < logs.length; i++) ...[
              _recordRow(c, logs[i]),
              if (i != logs.length - 1)
                Divider(color: c.softBorder, height: 16),
            ],
        ],
      ),
    );
  }

  Widget _recordRow(AppColors c, RemoteLoginLog log) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                log.ip.isEmpty ? '未知 IP' : log.ip,
                style: AppTextStyles.body.copyWith(color: c.textPrimary),
              ),
              const SizedBox(width: 8),
              if (log.remind)
                AppBadge(
                  text: '异常',
                  background: c.dangerSoft,
                  textColor: c.danger,
                  fontSize: 10,
                  height: 18,
                ),
            ],
          ),
        ),
        Text(
          log.dateDisplay,
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.fallbackLetter,
    required this.size,
  });

  final String url;
  final String fallbackLetter;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _letterAvatar(c),
        ),
      );
    }

    return _letterAvatar(c);
  }

  Widget _letterAvatar(AppColors c) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppConfig.brandGradient,
      ),
      child: Text(
        fallbackLetter,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Compact-layout widgets + helpers (original MobileProfilePage, verbatim)

class _TrafficOverviewCard extends StatelessWidget {
  const _TrafficOverviewCard({
    required this.usedGb,
    required this.totalGb,
    required this.remainGb,
    required this.resetDay,
    required this.onTap,
  });

  final double usedGb;
  final double totalGb;
  final double remainGb;
  final int? resetDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final progress = totalGb <= 0 ? 0.0 : (usedGb / totalGb).clamp(0.0, 1.0);
    final percent = (progress * 100).toStringAsFixed(0);
    final reset = resetDay == null || resetDay == 0
        ? '重置日 --'
        : '每月 $resetDay 日重置';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SmallIcon(icon: LucideIcons.gauge, color: c.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '流量概览',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${remainGb.toStringAsFixed(1)} GB',
                  style: AppTextStyles.largeNumber(
                    fontSize: 24,
                  ).copyWith(color: c.textPrimary),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '剩余',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: c.surfaceMuted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress > 0.85 ? c.warning : c.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已用 ${usedGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ),
                Text(
                  reset,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.type, required this.ctrl});

  final String type;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    if (_isPlanSummary(type)) {
      return _InfoSummaryCard(
        icon: LucideIcons.package,
        title: '当前套餐',
        value: ctrl.user.plan.isEmpty ? '暂无套餐' : ctrl.user.plan,
      );
    }

    if (_isExpireSummary(type)) {
      return _InfoSummaryCard(
        icon: LucideIcons.calendarClock,
        title: '到期时间',
        value: ctrl.user.expiry.isEmpty ? '--' : ctrl.user.expiry,
      );
    }

    return _TrafficOverviewCard(
      usedGb: ctrl.traffic.usedGb,
      totalGb: ctrl.traffic.totalGb,
      remainGb: ctrl.traffic.remainGb,
      resetDay: ctrl.resetDay,
      onTap: () => ctrl.goToPage(AppPage.traffic),
    );
  }
}

class _InfoSummaryCard extends StatelessWidget {
  const _InfoSummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Row(
        children: [
          _SmallIcon(icon: icon, color: c.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isPlanSummary(String type) {
  return type == 'plan' || type == 'currentPlan';
}

bool _isExpireSummary(String type) {
  return type == 'expire' || type == 'expireDate';
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 17),
    );
  }
}

class _LogoutSheet extends StatelessWidget {
  const _LogoutSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: '退出登录',
      subtitle: '当前登录状态和本地节点缓存将被清除',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.circleAlert, color: c.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '确认退出当前账号？退出后需要重新登录。',
                  style: AppTextStyles.caption.copyWith(
                    color: c.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 42,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: c.danger),
                  child: const Text('确认退出'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userName,
    required this.plan,
    required this.expiry,
    required this.avatar,
    required this.hidePlan,
    required this.hideExpiry,
    required this.onManage,
  });

  final String userName;
  final String plan;
  final String expiry;
  final String avatar;
  final bool hidePlan;
  final bool hideExpiry;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Row(
        children: [
          _ProfileAvatar(avatar: avatar),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isEmpty ? '--' : userName,
                  style: AppTextStyles.bodyStrong.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 3),
                if (!hidePlan)
                  Text(
                    '当前套餐：${plan.isEmpty ? '暂无套餐' : plan}',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                if (!hideExpiry && expiry.isNotEmpty)
                  Text(
                    '到期：$expiry',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onManage,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.slidersHorizontal,
                    color: c.primary,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '管理',
                    style: AppTextStyles.caption.copyWith(
                      color: c.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatar});

  final String avatar;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final url = AppConfig.avatarUrl.trim();
    final fallback = Text(
      avatar.isEmpty ? 'L' : avatar,
      style: AppTextStyles.bodyStrong.copyWith(color: c.primary),
    );

    if (url.isEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: c.primarySoft,
        child: fallback,
      );
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: c.primarySoft,
      foregroundImage: NetworkImage(url),
      onForegroundImageError: (_, _) {},
      child: fallback,
    );
  }
}

class _ProfileMenuSection extends StatelessWidget {
  const _ProfileMenuSection({required this.ctrl});

  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final item in MobileLayout.profileMenu)
        _MenuEntry(
          icon: _profileMenuIcon(item.icon, item.type),
          title: item.title.isEmpty ? _profileMenuTitle(item.type) : item.title,
          subtitle: item.subtitle.isEmpty
              ? _profileMenuSubtitle(item.type)
              : item.subtitle,
          page: _profileMenuPage(item.type),
        ),
      const _MenuEntry(
        icon: LucideIcons.settings,
        title: '系统设置',
        subtitle: '网络、代理与外观',
        page: AppPage.settings,
      ),
    ];

    if (MobileLayout.profileMenuLayout == 'list') {
      return Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _MenuListTile(
              icon: items[i].icon,
              title: items[i].title,
              subtitle: items[i].subtitle,
              onTap: () => ctrl.goToProfileChildPage(items[i].page),
            ),
            if (i + 1 < items.length) const SizedBox(height: 10),
          ],
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.58,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final item in items)
          _MenuTile(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            onTap: () => ctrl.goToProfileChildPage(item.page),
          ),
      ],
    );
  }
}

class _MenuEntry {
  const _MenuEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppPage page;
}

class _MenuListTile extends StatelessWidget {
  const _MenuListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: c.primary, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(LucideIcons.chevronRight, size: 18, color: c.iconMuted),
          ],
        ),
      ),
    );
  }
}

AppPage _profileMenuPage(String type) {
  return switch (type) {
    'wallet' => AppPage.wallet,
    'orders' => AppPage.orders,
    'tickets' => AppPage.tickets,
    'traffic' => AppPage.traffic,
    'invite' => AppPage.invite,
    'shop' => AppPage.shop,
    _ => AppPage.settings,
  };
}

String _profileMenuTitle(String type) {
  return switch (type) {
    'wallet' => '我的钱包',
    'orders' => '订单记录',
    'tickets' => '工单支持',
    'traffic' => '用量统计',
    'invite' => '邀请返佣',
    'shop' => '套餐购买',
    _ => '功能',
  };
}

String _profileMenuSubtitle(String type) {
  return switch (type) {
    'wallet' => '余额、佣金与账户充值',
    'orders' => '查看购买记录与支付状态',
    'tickets' => '联系在线客服',
    'traffic' => '查看流量与近期记录',
    'invite' => '邀请好友获得返佣奖励',
    'shop' => '选择适合你的流量方案',
    _ => '',
  };
}

IconData _profileMenuIcon(String icon, String type) {
  final name = icon.isEmpty ? type : icon;
  return switch (name) {
    'wallet' => LucideIcons.wallet,
    'walletCards' => LucideIcons.walletCards,
    'orders' || 'clipboardList' => LucideIcons.clipboardList,
    'tickets' || 'messageSquare' => LucideIcons.messageSquare,
    'traffic' || 'gauge' => LucideIcons.gauge,
    'invite' || 'gift' => LucideIcons.gift,
    'shop' || 'shoppingBag' => LucideIcons.shoppingBag,
    _ => LucideIcons.circle,
  };
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.softBorder),
          boxShadow: AppShadows.soft(c),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: c.primary, size: 19),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountManageSheet extends StatelessWidget {
  const _AccountManageSheet({
    required this.remindExpire,
    required this.remindTraffic,
    required this.autoRenewal,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
    required this.onChangePassword,
    required this.onLogout,
  });

  final bool remindExpire;
  final bool remindTraffic;
  final bool autoRenewal;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: '账号管理',
      children: [
        _SwitchRow(
          icon: LucideIcons.calendarClock,
          title: '到期提醒',
          subtitle: '接收账户到期提醒邮件',
          value: remindExpire,
          onChanged: onExpireChanged,
        ),
        _Divider(color: c.softBorder),
        _SwitchRow(
          icon: LucideIcons.gauge,
          title: '流量提醒',
          subtitle: '接收流量用尽提醒邮件',
          value: remindTraffic,
          onChanged: onTrafficChanged,
        ),
        _Divider(color: c.softBorder),
        _SwitchRow(
          icon: LucideIcons.refreshCw,
          title: '自动续费',
          subtitle: '到期前自动续费套餐',
          value: autoRenewal,
          onChanged: onAutoRenewalChanged,
        ),
        _Divider(color: c.softBorder),
        _ActionRow(
          icon: LucideIcons.lockKeyhole,
          title: '修改密码',
          subtitle: '更新登录密码',
          onTap: onChangePassword,
        ),
        _Divider(color: c.softBorder),
        _ActionRow(
          icon: LucideIcons.logOut,
          title: '退出登录',
          subtitle: '退出当前账号',
          danger: true,
          onTap: onLogout,
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: c.primary, size: 19),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = danger ? c.danger : c.primary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: danger ? c.danger : c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(color: c.textMuted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final oldPassword = _oldCtrl.text.trim();
    final newPassword = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (oldPassword.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      AppToast.show(context, '请填写完整密码信息', type: AppToastType.warning);
      return;
    }
    if (newPassword != confirm) {
      AppToast.show(context, '两次输入的新密码不一致', type: AppToastType.warning);
      return;
    }
    if (newPassword.length < 8) {
      AppToast.show(context, '新密码至少 8 位', type: AppToastType.warning);
      return;
    }

    setState(() => _submitting = true);
    try {
      await AppScope.of(context).changePasswordApi(
        oldPassword: oldPassword,
        newPassword: newPassword,
        passwordConfirmation: confirm,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(context, '密码已更新', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(
        context,
        e.toString().replaceFirst('ApiException: ', ''),
        type: AppToastType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBottomSheet(
      title: '修改密码',
      children: [
        _PasswordField(controller: _oldCtrl, label: '当前密码'),
        const SizedBox(height: 12),
        _PasswordField(controller: _newCtrl, label: '新密码'),
        const SizedBox(height: 12),
        _PasswordField(controller: _confirmCtrl, label: '确认新密码'),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.lockKeyhole, size: 17),
            label: Text(_submitting ? '更新中...' : '确认修改'),
          ),
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: c.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: true,
          style: AppTextStyles.input.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: '请输入$label',
            hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
            filled: true,
            fillColor: c.surfaceMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.softBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide(color: c.primary),
            ),
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: color);
  }
}

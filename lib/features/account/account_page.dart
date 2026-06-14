import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/api_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _loading = true;
  String? _error;
  RemoteUser? _user;
  List<RemoteLoginLog> _loginLogs = [];
  bool _initialized = false;

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
      } catch (_) {}
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

  @override
  Widget build(BuildContext context) {
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
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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

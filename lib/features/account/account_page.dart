import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/config/app_config.dart';
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
  String _subscribeUrl = '';
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
      String url = '';
      try {
        url = await api.getSubscribeUrl();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _user = user;
          _subscribeUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('ApiException: ', '');
          _loading = false;
        });
      }
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
          Row(
            children: [
              const Expanded(
                child: PageHeader(title: '我的账户', subtitle: '查看账户信息与订阅详情'),
              ),
              if (!_loading)
                RefreshIconButton(onTap: _load),
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
              subscribeUrl: _subscribeUrl,
              onCopy: _copy,
            ),
        ],
      ),
    );
  }
}

class _AccountContent extends StatelessWidget {
  const _AccountContent({
    required this.user,
    required this.subscribeUrl,
    required this.onCopy,
  });

  final RemoteUser user;
  final String subscribeUrl;
  final void Function(String text, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AccountInfoCard(user: user, onCopy: onCopy),
        const SizedBox(height: 14),
        _SubscriptionCard(
            user: user, subscribeUrl: subscribeUrl, onCopy: onCopy),
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

    final balanceYuan = user.balance / 100.0;

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
              Text('账户信息',
                  style: AppTextStyles.cardTitle
                      .copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: '邮箱',
            value: user.email,
            trailing: _CopyButton(
              onTap: () => onCopy(user.email, '邮箱'),
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: '账户余额',
            value: '¥${balanceYuan.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('账户状态',
                    style: AppTextStyles.caption.copyWith(color: c.textMuted)),
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
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.user,
    required this.subscribeUrl,
    required this.onCopy,
  });

  final RemoteUser user;
  final String subscribeUrl;
  final void Function(String, String) onCopy;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    final totalGb = user.transferEnable / AppConfig.bytesPerGb;
    final usedGb = user.used / AppConfig.bytesPerGb;
    final remainGb = (totalGb - usedGb).clamp(0.0, double.infinity);
    final ratio = totalGb > 0 ? (usedGb / totalGb).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      radius: AppRadius.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendar, size: 15, color: c.primary),
              const SizedBox(width: 8),
              Text('订阅信息',
                  style: AppTextStyles.cardTitle
                      .copyWith(color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(label: '到期时间', value: user.expiryDisplay),
          const SizedBox(height: 16),
          Text('流量使用',
              style: AppTextStyles.caption.copyWith(color: c.textMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 8, color: c.surfaceMuted),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: ratio > 0.8 ? c.danger : c.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已用 ${usedGb.toStringAsFixed(1)} GB',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              Text(
                '剩余 ${remainGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB',
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
          if (subscribeUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoRow(
              label: '订阅地址',
              value: subscribeUrl.length > 36
                  ? '${subscribeUrl.substring(0, 36)}…'
                  : subscribeUrl,
              trailing: _CopyButton(
                onTap: () => onCopy(subscribeUrl, '订阅地址'),
              ),
            ),
          ],
        ],
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
          child: Text(label,
              style: AppTextStyles.caption.copyWith(color: c.textMuted)),
        ),
        Expanded(
          child: Text(value,
              style: AppTextStyles.body.copyWith(color: c.textPrimary)),
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

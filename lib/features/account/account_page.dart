import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/config/app_config.dart';
import '../../shared/models/api_models.dart';
import '../../shared/services/panel_api.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_palette.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/page_status_cards.dart';
import '../shop/payment_dialog.dart';

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
      if (mounted) {
        setState(() {
          _user = user;
          _loginLogs = logs;
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

  Future<void> _openRechargeDialog() async {
    final ctrl = AppScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (_) => _RechargeDialog(
        api: ctrl.api,
        currencySymbol: ctrl.currencySymbol,
      ),
    );
    unawaited(_load());
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
              if (!_loading) RefreshIconButton(onTap: _load),
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
              onRecharge: _openRechargeDialog,
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
    required this.onRecharge,
  });

  final RemoteUser user;
  final List<RemoteLoginLog> loginLogs;
  final void Function(String text, String label) onCopy;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AccountInfoCard(user: user, onCopy: onCopy, onRecharge: onRecharge),
        const SizedBox(height: 14),
        _SubscriptionCard(user: user),
        const SizedBox(height: 14),
        _LoginRecordsCard(logs: loginLogs),
      ],
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.user,
    required this.onCopy,
    required this.onRecharge,
  });

  final RemoteUser user;
  final void Function(String, String) onCopy;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final currency = AppScope.of(context).currencySymbol;

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
          _InfoRow(
            label: '账户余额',
            value: '$currency${balanceYuan.toStringAsFixed(2)}',
            trailing: _RechargeButton(onTap: onRecharge),
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
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.user});

  final RemoteUser user;

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
              Text(
                '订阅信息',
                style: AppTextStyles.cardTitle.copyWith(color: c.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(label: '到期时间', value: user.expiryDisplay),
          const SizedBox(height: 16),
          Text(
            '流量使用',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
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
              Text(
                '已用 ${usedGb.toStringAsFixed(1)} GB',
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
              Text(
                '剩余 ${remainGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB',
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ),
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

class _RechargeButton extends StatelessWidget {
  const _RechargeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: c.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            '充值',
            style: AppTextStyles.button.copyWith(
              color: c.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
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
              if (i != logs.length - 1) Divider(color: c.softBorder, height: 16),
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

// ── Recharge Dialog ───────────────────────────────────────────────────────────

class _RechargeDialog extends StatefulWidget {
  const _RechargeDialog({required this.api, required this.currencySymbol});

  final PanelApi api;
  final String currencySymbol;

  @override
  State<_RechargeDialog> createState() => _RechargeDialogState();
}

class _RechargeDialogState extends State<_RechargeDialog> {
  static const _presets = [10, 30, 50, 100];

  int? _selectedPreset;
  final _customCtrl = TextEditingController();
  bool _useCustom = false;
  bool _submitting = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  int? get _amountYuan {
    if (_useCustom) return int.tryParse(_customCtrl.text.trim());
    return _selectedPreset;
  }

  Future<void> _submit() async {
    final yuan = _amountYuan;
    if (yuan == null || yuan <= 0) {
      AppToast.show(context, '请输入有效的充值金额', type: AppToastType.warning);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final tradeNo = await widget.api.submitRechargeOrder(yuan * 100);
      if (!mounted) return;
      await showOrderPaymentDialog(
        context: context,
        tradeNo: tradeNo,
        finalPrice: yuan.toDouble(),
        api: widget.api,
        currencySymbol: widget.currencySymbol,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.show(
          context,
          e.toString().replaceFirst('ApiException: ', ''),
          type: AppToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(c),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择充值金额',
                      style: AppTextStyles.sectionTitle
                          .copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: 14),
                    _buildPresets(c),
                    const SizedBox(height: 14),
                    _buildCustomInput(c),
                    const SizedBox(height: 24),
                    _buildConfirmButton(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.softBorder)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.wallet, size: 16, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '钱包充值',
              style:
                  AppTextStyles.pageTitle.copyWith(color: c.textPrimary),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Icon(LucideIcons.x, size: 16, color: c.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets(AppColors c) {
    return Row(
      children: _presets.map((amount) {
        final sel = !_useCustom && _selectedPreset == amount;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedPreset = amount;
              _useCustom = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(right: 8),
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? c.primarySoft : c.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: sel ? c.primary : c.border,
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.currencySymbol}$amount',
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: sel ? c.primary : c.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomInput(AppColors c) {
    return GestureDetector(
      onTap: () => setState(() => _useCustom = true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _useCustom ? c.primarySoft : c.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _useCustom ? c.primary : c.border,
            width: _useCustom ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              widget.currencySymbol,
              style: AppTextStyles.body.copyWith(
                color: _useCustom ? c.primary : c.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _customCtrl,
                keyboardType: TextInputType.number,
                onTap: () => setState(() => _useCustom = true),
                onChanged: (_) => setState(() => _useCustom = true),
                style: AppTextStyles.body.copyWith(color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: '自定义金额',
                  hintStyle: AppTextStyles.body
                      .copyWith(color: c.textMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmButton(AppColors c) {
    final enabled = _amountYuan != null && _amountYuan! > 0 && !_submitting;
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: enabled ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled ? AppPalette.brandGradient : null,
            color: enabled ? null : c.border,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Center(
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    '确认充值',
                    style: AppTextStyles.button.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

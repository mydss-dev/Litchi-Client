import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/plan_presentation.dart';
import '../../config/app_config.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_account_labels.dart';
import '../ui/v3_components.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_logout_confirmation.dart';
import '../ui/v3_toast.dart';
import 'v3_telegram_page.dart';
import 'v3_wallet_actions.dart';

/// Account layout: identity/plan hero, wallet, then preferences and security
/// — all directly visible. Do not turn the account into a collapsed menu.
/// Telegram binding is a bottom action; redemption lives in the window bar
/// (desktop) or the compact 更多 list (mobile).
class V3AccountPage extends StatefulWidget {
  const V3AccountPage({super.key});
  @override
  State<V3AccountPage> createState() => _V3AccountPageState();
}

class _V3AccountPageState extends State<V3AccountPage> {
  bool _updatingPreferences = false;

  Future<void> _updatePreferences({bool? remindExpire, bool? remindTraffic,
      bool? autoRenewal}) async {
    if (_updatingPreferences) return;
    final controller = AppScope.read(context);
    setState(() => _updatingPreferences = true);
    try {
      final error = await controller.updateUserSettings(
        remindExpire: remindExpire ?? controller.user.remindExpire,
        remindTraffic: remindTraffic ?? controller.user.remindTraffic,
        autoRenewal: autoRenewal ?? controller.user.autoRenewal,
      );
      if (!mounted) return;
      V3Toast.show(context, error ?? v3Copy(context, zh: '账户设置已更新',
        en: 'Account preferences updated', tw: '帳戶設定已更新'),
        type: error == null ? V3ToastType.success : V3ToastType.error);
    } catch (error) {
      if (mounted) {
        V3Toast.show(context, v3Copy(context,
          zh: '更新账户偏好失败：$error',
          en: 'Could not update account preferences: $error',
          tw: '更新帳戶偏好失敗：$error'), type: V3ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _updatingPreferences = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showV3LogoutConfirmation(context);
    if (!confirmed || !mounted) return;
    await AppScope.read(context).logout();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(
          kicker: v3Copy(context, zh: '账户中心',
            en: 'ACCOUNT CENTER', tw: '帳戶中心'),
          title: v3Copy(context, zh: '我的账户',
            en: 'My account', tw: '我的帳戶'),
          description: v3Copy(context,
            zh: '余额、偏好与安全设置集中管理。',
            en: 'Balance, preferences and security in one place.',
            tw: '餘額、偏好與安全設定集中管理。'),
          trailing: IconButton(tooltip: v3Copy(context,
              zh: '刷新账户数据', en: 'Refresh account', tw: '重新整理帳戶資料'),
            onPressed: controller.refreshData,
            icon: const Icon(Icons.refresh_rounded)),
        ),
        const SizedBox(height: 18),
        _AccountSummaryPanel(controller: controller),
        if (AppConfig.panelFeatures.wallet || controller.user.balance > 0 ||
            controller.withdrawable > 0) ...[
          const SizedBox(height: 16),
          const _WalletPanel(),
        ],
        if (controller.hasPlan) ...[
          const SizedBox(height: 16),
          _PreferencesPanel(controller: controller,
            busy: _updatingPreferences,
            onExpireChanged: (v) => _updatePreferences(remindExpire: v),
            onTrafficChanged: (v) => _updatePreferences(remindTraffic: v),
            onAutoRenewalChanged: (v) => _updatePreferences(autoRenewal: v)),
        ],
        const SizedBox(height: 16),
        _AccountActions(
          onPassword: () => showDialog<void>(context: context,
            barrierColor: Colors.black.withValues(alpha: .48),
            builder: (_) => const _PasswordDialog()),
          onTelegram: () => V3TelegramPage.show(context),
          onLogout: _confirmLogout),
        if (controller.dataLoadError != null) ...[
          const SizedBox(height: 16),
          Container(width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.warning.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(V3Radius.card)),
            child: Text(controller.dataLoadError!,
              style: TextStyle(color: p.warningInk, fontSize: 11))),
        ],
      ]),
    );
  }
}

class _AccountSummaryPanel extends StatelessWidget {
  const _AccountSummaryPanel({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final plan = PlanPresentation.fromController(controller);
    final letter = user.avatarLetter.trim().isEmpty
        ? 'L' : user.avatarLetter.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.lychee,
              borderRadius: BorderRadius.circular(V3Radius.card)),
            child: Text(letter, style: TextStyle(
              color: p.onLychee, fontSize: 19, fontWeight: FontWeight.w900))),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
              Text(v3AccountDisplayName(context, user.name),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink, fontSize: 16,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(v3AccountEmailLabel(context, controller.accountDetails?.email),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.inkMuted, fontSize: 11)),
            ])),
          const SizedBox(width: 12),
          // The badge speaks account standing: green while normal, amber
          // when the plan needs renewal or traffic, red on ban.
          V3StatusBadge(label: plan.status,
            color: switch (plan.status) {
              '正常' => p.success,
              '封禁' => p.danger,
              '到期' || '流量已用尽' => p.warning,
              _ => p.inkMuted,
            }, compact: true),
        ]),
        const SizedBox(height: 20),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v3Copy(context, zh: '当前套餐',
                en: 'CURRENT PLAN', tw: '目前方案'),
                style: TextStyle(color: p.inkMuted,
                  fontSize: 10, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Text(plan.shortLabel, maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink, fontSize: 18,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(plan.expiry, style: Theme.of(context).textTheme.bodySmall),
            ])),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: () => controller.goToPage(AppPage.shop),
            style: FilledButton.styleFrom(backgroundColor: p.lychee,
              foregroundColor: p.onLychee,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V3Radius.field))),
            icon: const Icon(Icons.storefront_rounded, size: 17),
            label: Text(controller.hasPlan
              ? v3Copy(context, zh: '管理套餐', en: 'Manage plan', tw: '管理方案')
              : v3Copy(context, zh: '选择套餐', en: 'Choose plan', tw: '選擇方案'))),
        ]),
      ]),
    );
  }
}

class _WalletPanel extends StatelessWidget {
  const _WalletPanel();
  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.panel)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v3Copy(context, zh: '钱包', en: 'WALLET', tw: '錢包'),
          style: TextStyle(color: p.inkMuted, fontSize: 10,
            fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _MoneyStat(label: v3Copy(context,
              zh: '账户余额', en: 'Account balance', tw: '帳戶餘額'),
            value: '$symbol${(controller.user.balance / 100).toStringAsFixed(2)}')),
          Container(width: 1, height: 46, color: p.line),
          const SizedBox(width: 22),
          Expanded(child: _MoneyStat(label: v3Copy(context,
              zh: '可提现佣金', en: 'Available commission', tw: '可提領佣金'),
            value: '$symbol${controller.withdrawable.toStringAsFixed(2)}')),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          if (AppConfig.panelFeatures.wallet) ...[
            Expanded(child: _WalletActionButton(
              icon: Icons.add_card_rounded,
              label: v3Copy(context, zh: '充值', en: 'Top up', tw: '儲值'),
              primary: true, onTap: () => showV3RechargeDialog(context))),
            const SizedBox(width: 10),
          ],
          Expanded(child: _WalletActionButton(
            icon: Icons.account_balance_rounded,
            label: v3Copy(context, zh: '提现', en: 'Withdraw', tw: '提領'),
            onTap: () => showV3WithdrawDialog(context))),
          const SizedBox(width: 10),
          Expanded(child: _WalletActionButton(
            icon: Icons.swap_horiz_rounded,
            label: v3Copy(context, zh: '划转', en: 'Transfer', tw: '轉帳'),
            onTap: () => showV3TransferDialog(context))),
        ]),
      ]),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.inkMuted, fontSize: 10,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(color: p.ink, fontSize: 20,
        fontWeight: FontWeight.w900)),
    ]);
  }
}

class _WalletActionButton extends StatelessWidget {
  const _WalletActionButton({required this.icon, required this.label,
    required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.field));
    return SizedBox(height: 46,
      child: primary
        ? FilledButton.icon(onPressed: onTap,
            style: FilledButton.styleFrom(backgroundColor: p.lychee,
              foregroundColor: p.onLychee, padding: EdgeInsets.zero, shape: shape),
            icon: Icon(icon, size: 17), label: Text(label))
        : OutlinedButton.icon(onPressed: onTap,
            style: OutlinedButton.styleFrom(foregroundColor: p.ink,
              side: BorderSide(color: p.line), padding: EdgeInsets.zero,
              shape: shape),
            icon: Icon(icon, size: 17), label: Text(label)),
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({required this.controller, required this.busy,
    required this.onExpireChanged, required this.onTrafficChanged,
    required this.onAutoRenewalChanged});
  final AppController controller;
  final bool busy;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.panel), border: Border.all(color: p.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(v3Copy(context, zh: '账户偏好',
            en: 'ACCOUNT PREFERENCES', tw: '帳戶偏好'),
            style: TextStyle(color: p.inkMuted, fontSize: 10,
              fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          const Spacer(),
          if (busy) const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 12),
        _PreferenceRow(title: v3Copy(context, zh: '到期提醒',
            en: 'Expiry reminder', tw: '到期提醒'),
          subtitle: v3Copy(context, zh: '套餐接近到期时提醒我',
            en: 'Notify me when the plan is near expiry',
            tw: '方案即將到期時提醒我'),
          value: controller.user.remindExpire,
          onChanged: busy ? null : onExpireChanged),
        Divider(color: p.line, height: 1),
        _PreferenceRow(title: v3Copy(context, zh: '流量提醒',
            en: 'Data reminder', tw: '流量提醒'),
          subtitle: v3Copy(context, zh: '剩余流量不足时提醒我',
            en: 'Notify me when data runs low', tw: '剩餘流量不足時提醒我'),
          value: controller.user.remindTraffic,
          onChanged: busy ? null : onTrafficChanged),
        Divider(color: p.line, height: 1),
        _PreferenceRow(title: v3Copy(context, zh: '自动续费',
            en: 'Auto-renewal', tw: '自動續費'),
          subtitle: v3Copy(context, zh: '允许服务端在条件满足时自动续费',
            en: 'Allow the service to renew when eligible',
            tw: '允許服務端在符合條件時自動續費'),
          value: controller.user.autoRenewal,
          onChanged: busy ? null : onAutoRenewalChanged),
      ]),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({required this.title, required this.subtitle,
    required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: p.ink, fontSize: 12,
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: p.inkMuted, fontSize: 10)),
          ])),
        V3Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.onPassword, required this.onTelegram,
    required this.onLogout});
  final VoidCallback onPassword;
  final VoidCallback onTelegram;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.card)),
      child: Row(children: [
        Expanded(child: _AccountAction(icon: Icons.password_rounded,
          label: v3Copy(context, zh: '修改密码',
            en: 'Change password', tw: '修改密碼'), onTap: onPassword)),
        Expanded(child: _AccountAction(
          key: const ValueKey('v3-account-telegram'),
          icon: Icons.send_rounded,
          label: v3Copy(context, zh: 'TG 通知',
            en: 'Telegram', tw: 'TG 通知'),
          onTap: onTelegram)),
        Expanded(child: _AccountAction(icon: Icons.logout_rounded,
          label: v3Copy(context, zh: '退出登录',
            en: 'Log out', tw: '登出'),
          danger: true, onTap: onLogout)),
      ]),
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({super.key, required this.icon, required this.label,
    required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(borderRadius: BorderRadius.circular(V3Radius.field), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 13,
        horizontal: 6),
        child: Column(children: [
          Icon(icon, size: 18, color: danger ? p.danger : p.inkMuted),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: danger ? p.danger : p.ink,
            fontSize: 10, fontWeight: FontWeight.w700)),
        ])),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose(); _next.dispose(); _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || _next.text.isEmpty || _confirmation.text.isEmpty) {
      setState(() => _error = v3Copy(context, zh: '请完整填写密码',
        en: 'Fill in all password fields', tw: '請完整填寫密碼'));
      return;
    }
    if (_next.text != _confirmation.text) {
      setState(() => _error = v3Copy(context, zh: '两次输入的新密码不一致',
        en: 'New passwords do not match', tw: '兩次輸入的新密碼不一致'));
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AppScope.read(context).changePasswordApi(
        oldPassword: _old.text, newPassword: _next.text,
        passwordConfirmation: _confirmation.text);
      if (!mounted) return;
      // Capture the root overlay before popping so the feedback outlives
      // the dialog route.
      final overlay = Overlay.of(context, rootOverlay: true);
      final message = v3Copy(context, zh: '密码修改成功',
        en: 'Password changed', tw: '密碼修改成功');
      Navigator.of(context).pop();
      V3Toast.showInOverlay(overlay, message, type: V3ToastType.success);
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = '$error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(width: 430,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: p.surface,
          borderRadius: BorderRadius.circular(V3Radius.panel)),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(v3Copy(context, zh: '修改账户密码',
                  en: 'Change account password', tw: '修改帳戶密碼'),
                style: Theme.of(context).textTheme.headlineLarge)),
              IconButton(tooltip: v3Copy(context, zh: '关闭',
                  en: 'Close', tw: '關閉'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 18),
            _PasswordField(controller: _old, label: v3Copy(context,
              zh: '当前密码', en: 'Current password', tw: '目前密碼')),
            const SizedBox(height: 12),
            _PasswordField(controller: _next, label: v3Copy(context,
              zh: '新密码', en: 'New password', tw: '新密碼'),
              obscureText: _obscure,
              trailing: IconButton(tooltip: _obscure
                  ? v3Copy(context, zh: '显示密码',
                      en: 'Show password', tw: '顯示密碼')
                  : v3Copy(context, zh: '隐藏密码',
                      en: 'Hide password', tw: '隱藏密碼'),
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                  size: 18, color: p.inkMuted))),
            const SizedBox(height: 12),
            _PasswordField(controller: _confirmation, label: v3Copy(context,
              zh: '确认新密码', en: 'Confirm new password', tw: '確認新密碼'),
              obscureText: _obscure),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
            ],
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: FilledButton(onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: p.lychee,
                  foregroundColor: p.onLychee,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(V3Radius.field))),
                child: Text(_busy
                  ? v3Copy(context, zh: '正在提交…',
                      en: 'Submitting…', tw: '正在提交…')
                  : v3Copy(context, zh: '保存新密码',
                      en: 'Save password', tw: '儲存新密碼')))),
          ]))),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label,
    this.trailing, this.obscureText = true});
  final TextEditingController controller;
  final String label;
  final Widget? trailing;
  final bool obscureText;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextField(controller: controller, obscureText: obscureText,
      decoration: InputDecoration(labelText: label, filled: true,
        fillColor: p.surfaceRaised,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(V3Radius.field),
          borderSide: BorderSide.none),
        suffixIcon: trailing),
    );
  }
}

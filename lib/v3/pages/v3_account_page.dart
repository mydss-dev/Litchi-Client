import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../app/v3_nav.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';
import 'v3_telegram_page.dart';
import 'v3_wallet_actions.dart';

/// Account-owned destinations belong together, rather than being mixed into
/// the side rail or scattered between unrelated pages.
class V3AccountPage extends StatefulWidget {
  const V3AccountPage({super.key});

  @override
  State<V3AccountPage> createState() => _V3AccountPageState();
}

class _V3AccountPageState extends State<V3AccountPage> {
  bool _updating = false;

  Future<void> _update({bool? expire, bool? traffic, bool? renew}) async {
    if (_updating) return;
    final controller = AppScope.read(context);
    setState(() => _updating = true);
    final error = await controller.updateUserSettings(
      remindExpire: expire ?? controller.user.remindExpire,
      remindTraffic: traffic ?? controller.user.remindTraffic,
      autoRenewal: renew ?? controller.user.autoRenewal,
    );
    if (!mounted) return;
    setState(() => _updating = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? '账户设置已更新')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final walletEnabled = AppConfig.panelFeatures.wallet ||
        controller.user.balance > 0 || controller.withdrawable > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        V3PageHeader(kicker: '账户中心', title: '我的账户',
          trailing: IconButton(tooltip: '刷新账户数据',
            onPressed: controller.refreshData,
            icon: const Icon(Icons.refresh_rounded))),
        const SizedBox(height: 18),
        _IdentityCard(controller: controller),
        const SizedBox(height: 14),
        V3Panel(radius: 20, padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('账户服务', style: TextStyle(color: p.ink,
                fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 13),
              Row(children: [
                if (isPageEnabled(AppPage.orders)) ...[
                  Expanded(child: _ServiceTile(
                    key: hubRowKey(AppPage.orders),
                    icon: Icons.receipt_long_rounded, label: '订单记录',
                    onTap: () => openV3Page(context, AppPage.orders))),
                  const SizedBox(width: 8),
                ],
                if (walletEnabled) ...[
                  Expanded(child: _ServiceTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '我的钱包',
                    onTap: () => _openWallet(context))),
                  if (isPageEnabled(AppPage.giftCard))
                    const SizedBox(width: 8),
                ],
                if (isPageEnabled(AppPage.giftCard))
                  Expanded(child: _ServiceTile(
                    key: hubRowKey(AppPage.giftCard),
                    icon: Icons.card_giftcard_rounded, label: '兑换码',
                    onTap: () => openV3Page(context, AppPage.giftCard))),
              ]),
            ])),
        if (walletEnabled) ...[
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openWallet(context),
            child: V3Panel(radius: 20, tone: V3PanelTone.raised,
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('账户余额', style: TextStyle(color: p.inkMuted,
                      fontSize: 12)),
                    const SizedBox(height: 5),
                    Text('${controller.currencySymbol}${(controller.user.balance / 100).toStringAsFixed(2)}',
                      style: TextStyle(color: p.ink,
                        fontSize: 23, fontWeight: FontWeight.w900)),
                  ])),
                Text('钱包管理', style: TextStyle(color: p.lycheeInk,
                  fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: p.lycheeInk),
              ])),
          ),
        ],
        const SizedBox(height: 14),
        V3Panel(radius: 20, padding: const EdgeInsets.all(10),
          child: Theme(data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 10),
              title: Text('账户偏好与安全', style: TextStyle(color: p.ink,
                fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text('到期提醒、流量提醒、续费与密码',
                style: TextStyle(color: p.inkMuted, fontSize: 11)),
              children: [
                if (_updating) const LinearProgressIndicator(minHeight: 2),
                SwitchListTile.adaptive(
                  title: const Text('到期提醒'),
                  value: controller.user.remindExpire,
                  onChanged: _updating ? null : (v) => _update(expire: v)),
                SwitchListTile.adaptive(
                  title: const Text('流量提醒'),
                  value: controller.user.remindTraffic,
                  onChanged: _updating ? null : (v) => _update(traffic: v)),
                SwitchListTile.adaptive(
                  title: const Text('自动续费'),
                  value: controller.user.autoRenewal,
                  onChanged: _updating ? null : (v) => _update(renew: v)),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('修改密码'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showDialog<void>(context: context,
                    builder: (_) => const _PasswordDialog())),
              ],
            ),
          )),
        if (AppConfig.panelFeatures.telegram) ...[
          const SizedBox(height: 12),
          V3Panel(radius: 18, padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.send_rounded),
              title: const Text('Telegram 通知'),
              subtitle: Text(controller.accountDetails?.telegramId == null
                  ? '未绑定' : '已绑定'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => V3TelegramPage.show(context))),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: controller.logout,
          icon: Icon(Icons.logout_rounded, color: p.dangerInk),
          label: Text('退出登录',
            style: TextStyle(color: p.dangerInk))),
        if (controller.dataLoadError != null) ...[
          const SizedBox(height: 12),
          Text(controller.dataLoadError!,
            style: TextStyle(color: p.dangerInk, fontSize: 12)),
        ],
      ]),
    );
  }

  void _openWallet(BuildContext context) {
    final controller = AppScope.read(context);
    final p = V3Palette.of(context);
    showV3Sheet<void>(context, title: '我的钱包', builder: (_) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        V3Panel(tone: V3PanelTone.raised, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('账户余额', style: TextStyle(color: p.inkMuted,
              fontSize: 12)),
            const SizedBox(height: 5),
            Text('${controller.currencySymbol}${(controller.user.balance / 100).toStringAsFixed(2)}',
              style: TextStyle(color: p.ink,
                fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            Text('可提现佣金：${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
              style: TextStyle(color: p.inkMuted, fontSize: 12)),
          ])),
        const SizedBox(height: 18),
        if (AppConfig.panelFeatures.wallet) ...[
          V3ActionButton(label: '充值', icon: Icons.add_card_rounded,
            onPressed: () { closeV3Sheet(context); showV3RechargeDialog(context); }),
          const SizedBox(height: 10),
        ],
        V3ActionButton(label: '提现', secondary: true,
          icon: Icons.account_balance_rounded,
          onPressed: () { closeV3Sheet(context); showV3WithdrawDialog(context); }),
        const SizedBox(height: 10),
        V3ActionButton(label: '佣金划转', secondary: true,
          icon: Icons.swap_horiz_rounded,
          onPressed: () { closeV3Sheet(context); showV3TransferDialog(context); }),
      ]));
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final name = user.name.trim().isEmpty ? 'Litchi User' : user.name.trim();
    return V3Panel(radius: 20, padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(width: 46, height: 46, alignment: Alignment.center,
          decoration: BoxDecoration(color: p.lychee,
            borderRadius: BorderRadius.circular(14)),
          child: Text(user.avatarLetter.isEmpty ? 'L' : user.avatarLetter[0],
            style: const TextStyle(color: Colors.white,
              fontSize: 20, fontWeight: FontWeight.w900))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink,
                fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(controller.accountDetails?.email ?? 'Litchi 账户',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
            const SizedBox(height: 5),
            Text(controller.hasPlan
                ? '${user.plan.trim().isEmpty ? '已激活套餐' : user.plan.trim()} · ${controller.planExpiryLabel}'
                : '暂无套餐',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ])),
        const SizedBox(width: 8),
        IconButton(tooltip: '管理套餐',
          onPressed: () => controller.goToPage(AppPage.shop),
          icon: Icon(Icons.chevron_right_rounded, color: p.lycheeInk)),
      ]));
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({super.key, required this.icon,
    required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Icon(icon, size: 23, color: p.lycheeInk),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 12,
              fontWeight: FontWeight.w700)),
        ]),
      ));
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose(); _new.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || _new.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = '请完整填写密码');
      return;
    }
    if (_new.text != _confirm.text) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AppScope.read(context).changePasswordApi(
        oldPassword: _old.text, newPassword: _new.text,
        passwordConfirmation: _confirm.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码修改成功')));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(
      title: const Text('修改账户密码'),
      content: SizedBox(width: 390,
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: _old, obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码')),
            const SizedBox(height: 12),
            TextField(controller: _new, obscureText: true,
              decoration: const InputDecoration(labelText: '新密码')),
            const SizedBox(height: 12),
            TextField(controller: _confirm, obscureText: true,
              decoration: const InputDecoration(labelText: '确认新密码')),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(
                  color: p.dangerInk, fontSize: 12))),
          ]))),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消')),
        FilledButton(onPressed: _busy ? null : _submit,
          child: Text(_busy ? '提交中…' : '确认修改')),
      ],
    );
  }
}

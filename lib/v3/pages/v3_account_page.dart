import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';
import 'v3_telegram_page.dart';
import 'v3_wallet_actions.dart';

/// Account business stays here: orders, wallet and gift-card redemption.
/// Traffic, tickets and settings remain independent sidebar destinations.
class V3AccountPage extends StatefulWidget {
  const V3AccountPage({super.key});

  @override
  State<V3AccountPage> createState() => _V3AccountPageState();
}

class _V3AccountPageState extends State<V3AccountPage> {
  bool _updatingPreferences = false;

  Future<void> _updatePreferences({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updatingPreferences) return;
    final controller = AppScope.read(context);
    setState(() => _updatingPreferences = true);
    final error = await controller.updateUserSettings(
      remindExpire: remindExpire ?? controller.user.remindExpire,
      remindTraffic: remindTraffic ?? controller.user.remindTraffic,
      autoRenewal: autoRenewal ?? controller.user.autoRenewal,
    );
    if (!mounted) return;
    setState(() => _updatingPreferences = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '账户设置已更新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final hasWallet = AppConfig.panelFeatures.wallet ||
        controller.user.balance > 0 || controller.withdrawable > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: '账户中心',
            title: '我的账户',
            trailing: IconButton(
              tooltip: '刷新账户数据',
              onPressed: controller.refreshData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 18),
          _IdentityCard(controller: controller),
          const SizedBox(height: 14),
          Text('账户服务', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              if (isPageEnabled(AppPage.orders)) ...[
                Expanded(child: _ServiceTile(
                  icon: Icons.receipt_long_outlined,
                  label: '订单记录',
                  onTap: () => openV3Page(context, AppPage.orders),
                )),
                const SizedBox(width: 10),
              ],
              if (hasWallet) ...[
                Expanded(child: _ServiceTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: '我的钱包',
                  onTap: () => _showWallet(context),
                )),
                const SizedBox(width: 10),
              ],
              if (isPageEnabled(AppPage.giftCard))
                Expanded(child: _ServiceTile(
                  icon: Icons.card_giftcard_rounded,
                  label: '兑换码',
                  onTap: () => openV3Page(context, AppPage.giftCard),
                )),
            ],
          ),
          if (hasWallet) ...[
            const SizedBox(height: 14),
            _BalancePreview(controller: controller, onTap: () => _showWallet(context)),
          ],
          const SizedBox(height: 14),
          V3Panel(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('账户偏好与安全', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('通知、续费与密码', style: TextStyle(fontSize: 12)),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  if (_updatingPreferences) const LinearProgressIndicator(minHeight: 2),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('到期提醒'),
                    value: controller.user.remindExpire,
                    onChanged: _updatingPreferences ? null : (value) => _updatePreferences(remindExpire: value),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('流量提醒'),
                    value: controller.user.remindTraffic,
                    onChanged: _updatingPreferences ? null : (value) => _updatePreferences(remindTraffic: value),
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: const Text('自动续费'),
                    value: controller.user.autoRenewal,
                    onChanged: _updatingPreferences ? null : (value) => _updatePreferences(autoRenewal: value),
                  ),
                  if (AppConfig.panelFeatures.telegram)
                    ListTile(
                      leading: const Icon(Icons.send_rounded),
                      title: const Text('Telegram 通知'),
                      subtitle: Text(controller.accountDetails?.telegramId == null ? '未绑定' : '已绑定'),
                      onTap: () => V3TelegramPage.show(context),
                    ),
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('修改密码'),
                    onTap: () => showDialog<void>(context: context, builder: (_) => const _PasswordDialog()),
                  ),
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: p.dangerInk),
                    title: Text('退出登录', style: TextStyle(color: p.dangerInk)),
                    onTap: controller.logout,
                  ),
                ],
              ),
            ),
          ),
          if (controller.dataLoadError != null) ...[
            const SizedBox(height: 14),
            Text(controller.dataLoadError!, style: TextStyle(color: p.dangerInk)),
          ],
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final letter = user.avatarLetter.trim().isEmpty ? 'L' : user.avatarLetter.trim().substring(0, 1);
    return V3Panel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.lychee, borderRadius: BorderRadius.circular(15)),
            child: Text(letter.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name.isEmpty ? 'Litchi User' : user.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(controller.accountDetails?.email ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkMuted, fontSize: 11)),
                const SizedBox(height: 5),
                Text(controller.hasPlan
                    ? '${user.plan.trim().isEmpty ? '已激活套餐' : user.plan.trim()} · ${controller.planExpiryLabel}'
                    : '暂无套餐',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkMuted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.verified_rounded, size: 17,
              color: controller.hasPlan ? p.success : p.inkMuted),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: SizedBox(
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: p.lycheeInk),
              const SizedBox(height: 9),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalancePreview extends StatelessWidget {
  const _BalancePreview({required this.controller, required this.onTap});
  final AppController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      tone: V3PanelTone.raised,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('账户余额', style: TextStyle(color: p.inkMuted, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${controller.currencySymbol}${(controller.user.balance / 100).toStringAsFixed(2)}',
                    style: TextStyle(color: p.ink, fontSize: 23, fontWeight: FontWeight.w800)),
                ],
              )),
              Text('钱包管理', style: TextStyle(color: p.lycheeInk, fontSize: 12, fontWeight: FontWeight.w700)),
              Icon(Icons.chevron_right_rounded, color: p.lycheeInk),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showWallet(BuildContext context) => showV3Sheet<void>(
  context,
  title: '我的钱包',
  builder: (sheetContext) {
    final controller = AppScope.of(sheetContext);
    final p = V3Palette.of(sheetContext);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        V3Panel(tone: V3PanelTone.raised, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('账户余额', style: TextStyle(color: p.inkMuted)),
            const SizedBox(height: 4),
            Text('${controller.currencySymbol}${(controller.user.balance / 100).toStringAsFixed(2)}',
              style: TextStyle(color: p.ink, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text('可提现佣金 ${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
              style: TextStyle(color: p.inkMuted, fontSize: 12)),
          ],
        )),
        const SizedBox(height: 18),
        if (AppConfig.panelFeatures.wallet) ...[
          FilledButton.icon(onPressed: () => showV3RechargeDialog(sheetContext),
            icon: const Icon(Icons.add_card_rounded), label: const Text('充值')),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(onPressed: () => showV3WithdrawDialog(sheetContext),
          icon: const Icon(Icons.account_balance_rounded), label: const Text('提现')),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: () => showV3TransferDialog(sheetContext),
          icon: const Icon(Icons.swap_horiz_rounded), label: const Text('佣金划转')),
      ],
    );
  },
);

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
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() { _busy = false; _error = '$error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      title: const Text('修改密码'),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _old, obscureText: true,
            decoration: const InputDecoration(labelText: '原密码')),
          const SizedBox(height: 12),
          TextField(controller: _new, obscureText: true,
            decoration: const InputDecoration(labelText: '新密码')),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: true,
            decoration: const InputDecoration(labelText: '确认新密码')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: p.dangerInk)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('取消')),
        FilledButton(onPressed: _busy ? null : _save,
          child: Text(_busy ? '提交中…' : '确认修改')),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';
import 'v3_telegram_page.dart';
import 'v3_wallet_actions.dart';

/// Account business stays in one place: identity, orders, wallet, redemption,
/// preferences and security. Other primary destinations belong to the rail.
class V3AccountPage extends StatefulWidget {
  const V3AccountPage({super.key});

  @override
  State<V3AccountPage> createState() => _V3AccountPageState();
}

class _V3AccountPageState extends State<V3AccountPage> {
  bool _walletOpen = false;
  bool _preferencesOpen = false;
  bool _updating = false;

  Future<void> _updatePreferences({
    bool? remindExpire,
    bool? remindTraffic,
    bool? autoRenewal,
  }) async {
    if (_updating) return;
    final controller = AppScope.read(context);
    setState(() => _updating = true);
    final error = await controller.updateUserSettings(
      remindExpire: remindExpire ?? controller.user.remindExpire,
      remindTraffic: remindTraffic ?? controller.user.remindTraffic,
      autoRenewal: autoRenewal ?? controller.user.autoRenewal,
    );
    if (!mounted) return;
    setState(() => _updating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '账户设置已更新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final walletAvailable = AppConfig.panelFeatures.wallet ||
        controller.user.balance > 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 36),
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
          const SizedBox(height: 16),
          _IdentityCard(controller: controller),
          const SizedBox(height: 14),
          V3Panel(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
                  child: Text('账户服务', style: TextStyle(
                    color: p.ink, fontSize: 14, fontWeight: FontWeight.w800,
                  )),
                ),
                Row(
                  children: [
                    if (isPageEnabled(AppPage.orders)) ...[
                      Expanded(child: _ServiceTile(
                        icon: Icons.receipt_long_outlined,
                        label: '订单记录',
                        onTap: () => openV3Page(context, AppPage.orders),
                      )),
                      const SizedBox(width: 8),
                    ],
                    if (walletAvailable) ...[
                      Expanded(child: _ServiceTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: '我的钱包',
                        selected: _walletOpen,
                        onTap: () => setState(() => _walletOpen = !_walletOpen),
                      )),
                      const SizedBox(width: 8),
                    ],
                    if (isPageEnabled(AppPage.giftCard))
                      Expanded(child: _ServiceTile(
                        icon: Icons.card_giftcard_rounded,
                        label: '礼品卡兑换',
                        onTap: () => openV3Page(context, AppPage.giftCard),
                      )),
                  ],
                ),
              ],
            ),
          ),
          if (walletAvailable) ...[
            const SizedBox(height: 14),
            _WalletSummary(
              expanded: _walletOpen,
              onTap: () => setState(() => _walletOpen = !_walletOpen),
            ),
            if (_walletOpen) ...[
              const SizedBox(height: 8),
              const _WalletActions(),
            ],
          ],
          if (AppConfig.panelFeatures.telegram) ...[
            const SizedBox(height: 14),
            V3Panel(
              padding: EdgeInsets.zero,
              child: V3NavRow(
                icon: Icons.send_rounded,
                label: 'Telegram 通知',
                subtitle: controller.accountDetails?.telegramId == null ? '未绑定' : '已绑定',
                selected: false,
                onTap: () => V3TelegramPage.show(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          V3Panel(
            padding: EdgeInsets.zero,
            child: Column(children: [
              ListTile(
                title: Text('账户偏好', style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
                subtitle: Text('到期提醒 · 流量提醒 · 自动续费', style: TextStyle(color: p.inkMuted, fontSize: 11)),
                trailing: Icon(_preferencesOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                onTap: () => setState(() => _preferencesOpen = !_preferencesOpen),
              ),
              if (_preferencesOpen) ...[
                Divider(height: 1, color: p.line),
                if (_updating) const LinearProgressIndicator(minHeight: 2),
                _SwitchRow(
                  title: '到期提醒', value: controller.user.remindExpire,
                  onChanged: _updating ? null : (value) => _updatePreferences(remindExpire: value),
                ),
                _SwitchRow(
                  title: '流量提醒', value: controller.user.remindTraffic,
                  onChanged: _updating ? null : (value) => _updatePreferences(remindTraffic: value),
                ),
                _SwitchRow(
                  title: '自动续费', value: controller.user.autoRenewal,
                  onChanged: _updating ? null : (value) => _updatePreferences(autoRenewal: value),
                ),
              ],
              Divider(height: 1, color: p.line),
              ListTile(
                leading: Icon(Icons.lock_outline_rounded, color: p.inkMuted),
                title: const Text('修改密码'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showDialog<void>(
                  context: context, builder: (_) => const _PasswordDialog(),
                ),
              ),
              Divider(height: 1, color: p.line),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: p.dangerInk),
                title: Text('退出登录', style: TextStyle(color: p.dangerInk)),
                onTap: controller.logout,
              ),
            ]),
          ),
          if (controller.dataLoadError != null) ...[
            const SizedBox(height: 14),
            Text(controller.dataLoadError!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
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
    final name = user.name.trim().isEmpty ? 'Litchi User' : user.name.trim();
    return V3Panel(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.lychee, borderRadius: BorderRadius.circular(14)),
            child: Text(user.avatarLetter.isEmpty ? 'L' : user.avatarLetter.substring(0, 1),
              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(controller.accountDetails?.email ?? '', maxLines: 1,
                overflow: TextOverflow.ellipsis, style: TextStyle(color: p.inkMuted, fontSize: 12)),
            ],
          )),
          V3StatusBadge(
            label: controller.hasPlan ? '套餐有效' : '暂无套餐',
            color: controller.hasPlan ? p.success : p.inkMuted,
            compact: true,
          ),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: p.line),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(controller.hasPlan
                ? (user.plan.trim().isEmpty ? '已激活套餐' : user.plan.trim())
                : '还没有套餐',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(controller.hasPlan ? '有效期 ${controller.planExpiryLabel}' : '选择套餐后即可开始连接',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
          ])),
          const SizedBox(width: 8),
          TextButton(
            onPressed: isPageEnabled(AppPage.shop) ? () => controller.goToPage(AppPage.shop) : null,
            child: Text(controller.hasPlan ? '查看套餐' : '选择套餐'),
          ),
        ]),
      ]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.icon, required this.label, required this.onTap, this.selected = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? p.lycheeSoft : p.surfaceRaised,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? p.lycheeInk : p.line),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? p.lycheeInk : p.ink, size: 21),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  const _WalletSummary({required this.expanded, required this.onTap});
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return V3Panel(
      tone: V3PanelTone.raised,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('账户余额', style: TextStyle(color: p.inkMuted, fontSize: 12)),
              const SizedBox(height: 5),
              Text('${controller.currencySymbol}${(controller.user.balance / 100).toStringAsFixed(2)}',
                style: TextStyle(color: p.ink, fontSize: 22, fontWeight: FontWeight.w900)),
            ])),
            Text(expanded ? '收起钱包' : '钱包管理',
              style: TextStyle(color: p.lycheeInk, fontSize: 12, fontWeight: FontWeight.w800)),
            Icon(expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded, color: p.lycheeInk),
          ]),
        ),
      ),
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return V3Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('可提现佣金：${controller.currencySymbol}${controller.withdrawable.toStringAsFixed(2)}',
          style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (AppConfig.panelFeatures.wallet)
            FilledButton.icon(
              onPressed: () => showV3RechargeDialog(context),
              icon: const Icon(Icons.add_card_rounded, size: 17),
              label: const Text('充值'),
            ),
          OutlinedButton.icon(
            onPressed: () => showV3WithdrawDialog(context),
            icon: const Icon(Icons.account_balance_rounded, size: 17),
            label: const Text('提现'),
          ),
          OutlinedButton.icon(
            onPressed: () => showV3TransferDialog(context),
            icon: const Icon(Icons.swap_horiz_rounded, size: 17),
            label: const Text('划转'),
          ),
        ]),
      ]),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile(
    dense: true,
    title: Text(title, style: const TextStyle(fontSize: 13)),
    value: value,
    onChanged: onChanged,
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _old.dispose(); _next.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_old.text.isEmpty || _next.text.isEmpty || _confirm.text.isEmpty) {
      setState(() => _error = '请完整填写密码'); return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = '两次输入的新密码不一致'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await AppScope.read(context).changePasswordApi(
        oldPassword: _old.text,
        newPassword: _next.text,
        passwordConfirmation: _confirm.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码修改成功')),
      );
    } catch (error) {
      if (mounted) setState(() { _error = '$error'; _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const Expanded(child: Text('修改账户密码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(tooltip: '关闭', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: '当前密码')),
              const SizedBox(height: 10),
              TextField(controller: _next, obscureText: true, decoration: const InputDecoration(labelText: '新密码')),
              const SizedBox(height: 10),
              TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码')),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 12)),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _submit,
                child: Text(_busy ? '正在提交…' : '保存新密码')),
            ]),
        ),
      ),
    );
  }
}

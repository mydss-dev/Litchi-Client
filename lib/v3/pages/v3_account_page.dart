import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../app/v3_nav.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_sheet.dart';
import 'v3_telegram_page.dart';

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? '账户设置已更新')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final user = controller.user;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
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
              const SizedBox(height: 26),
              compact
                  ? Column(
                      children: [
                        _IdentityPanel(controller: controller),
                        const SizedBox(height: 16),
                        _PlanPanel(controller: controller),
                      ],
                    )
                  // Start, not stretch: the identity band is a band now, and
                  // stretching it to the plan card's height would rebuild the
                  // empty space it just lost.
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 11,
                          child: _IdentityPanel(controller: controller),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 9,
                          child: _PlanPanel(controller: controller),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              // Directly under the account summary, on every layout: on compact
              // this hub is the only route to wallet, orders, traffic, invite,
              // tickets and settings, and further down it sat a full screen
              // below the fold. Keeping one placement also means resizing the
              // window never moves a navigation landmark.
              _HubPanel(controller: controller),
              const SizedBox(height: 16),
              compact
                  ? Column(
                      children: [
                        _FinancePanel(controller: controller),
                        const SizedBox(height: 16),
                        _DevicePanel(controller: controller),
                      ],
                    )
                  // Sizes the taller of the two, so the pair still reads as one
                  // row of equal cards now that either may grow past the floor.
                  : IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _FinancePanel(controller: controller),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: _DevicePanel(controller: controller)),
                        ],
                      ),
                    ),
              const SizedBox(height: 16),
              _PreferencesPanel(
                controller: controller,
                busy: _updatingPreferences,
                onExpireChanged: (value) =>
                    _updatePreferences(remindExpire: value),
                onTrafficChanged: (value) =>
                    _updatePreferences(remindTraffic: value),
                onAutoRenewalChanged: (value) =>
                    _updatePreferences(autoRenewal: value),
              ),
              const SizedBox(height: 16),
              _AccountActions(
                onPassword: () => _showPasswordDialog(context),
                onLogout: controller.logout,
              ),
              if (controller.dataLoadError != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    controller.dataLoadError!,
                    style: TextStyle(color: p.warningInk, fontSize: 11),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                user.name.isEmpty ? 'LITCHI USER' : user.name,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPasswordDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => const _PasswordDialog(),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final user = controller.user;
    final letter = user.avatarLetter.trim().isEmpty
        ? 'L'
        : user.avatarLetter.trim().substring(0, 1).toUpperCase();

    // One row, not a stack. It used to be a 58dp avatar, a 28dp gap, a 22pt
    // name and an email line, spread down a panel half the width of the page —
    // four small facts holding up a large empty card. The same four facts fit
    // one band, with the badge where the eye already is.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.lychee,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name.trim().isEmpty ? 'Litchi User' : user.name.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.accountDetails?.email ?? 'Secure Litchi account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          V3StatusBadge(
            label: controller.hasPlan ? '套餐有效' : '暂无套餐',
            color: controller.hasPlan ? p.success : p.inkMuted,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final plan = controller.user.plan.trim();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前套餐',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            controller.hasPlan ? (plan.isEmpty ? '已激活套餐' : plan) : '还没有套餐',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 8),
          Text(
            controller.hasPlan
                ? '有效期 ${controller.planExpiryLabel}'
                : '选择套餐后即可开始连接',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: () => controller.goToPage(AppPage.shop),
              style: FilledButton.styleFrom(
                backgroundColor: p.lychee,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.storefront_rounded, size: 17),
              label: Text(controller.hasPlan ? '管理套餐' : '选择套餐'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancePanel extends StatelessWidget {
  const _FinancePanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final symbol = controller.currencySymbol;
    final balance = controller.user.balance / 100;
    return _MetricPanel(
      eyebrow: '钱包',
      title: '$symbol${balance.toStringAsFixed(2)}',
      subtitle: '账户余额',
      accent: p.lychee,
      trailing: controller.withdrawable > 0
          ? '佣金 $symbol${controller.withdrawable.toStringAsFixed(2)}'
          : null,
      onTap: () => openV3Page(context, AppPage.wallet),
    );
  }
}

class _DevicePanel extends StatelessWidget {
  const _DevicePanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final alive = controller.aliveIp;
    final limit = controller.deviceLimit;
    return _MetricPanel(
      eyebrow: '设备',
      title: alive == null ? '--' : '$alive',
      subtitle: limit == null ? '当前在线设备' : '在线设备 / 上限 $limit',
      accent: p.aqua,
      trailing: '${controller.traffic.remainGb.toStringAsFixed(1)} GB 剩余',
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.trailing,
    this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Color accent;
  final String? trailing;

  /// Turns the whole card into a target. Only the wallet card sets it: the card
  /// reports a balance the user can act on, so a card that reads 钱包 and does
  /// nothing when tapped is a dead end — 钱包 was otherwise reachable only by
  /// finding its row in the hub below.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final card = Container(
      // A floor, not a fixed height. The card holds three lines of text whose
      // length depends on the language and on the reader's text scale, and a
      // hard 128 clipped them: raising the 10px labels to the theme's floor was
      // by itself enough to overflow this box.
      constraints: const BoxConstraints(minHeight: 128),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 58,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  eyebrow,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: p.inkMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Flexible(
              child: Text(
                trailing!,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// What belongs to the account: money owed, money spent, money added.
///
/// It used to list six destinations, four of which were routing rather than
/// account business — traffic, invites, tickets and settings are shared with
/// the desktop rail and now live in the compact 更多 tab.
class _HubPanel extends StatelessWidget {
  const _HubPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final items = enabledNavItems(kMobileHub);
    // Telegram binding is a xiaoV2board-only capability, not a nav page, so it
    // is gated here rather than in the nav model.
    final telegramEnabled = AppConfig.panelFeatures.telegram;
    if (items.isEmpty && !telegramEnabled) return const SizedBox.shrink();
    final telegramBound = controller.accountDetails?.telegramId != null;
    return V3NavPanel(
      title: '我的服务',
      children: [
        for (final item in items)
          V3NavRow(
            key: hubRowKey(item.page),
            icon: item.icon,
            label: item.label,
            selected: controller.page == item.page,
            // Every row here is a modal now, so this neither changes the
            // page nor highlights a row: the sheet is the evidence that
            // something opened, and the account page is still behind it.
            onTap: () => openV3Page(context, item.page),
          ),
        if (telegramEnabled)
          V3NavRow(
            key: const ValueKey('v3-hub-telegram'),
            icon: Icons.send_rounded,
            label: 'Telegram 通知',
            subtitle: telegramBound ? '已绑定，可接收账户通知' : '未绑定',
            selected: false,
            onTap: () => V3TelegramPage.show(context),
          ),
      ],
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel({
    required this.controller,
    required this.busy,
    required this.onExpireChanged,
    required this.onTrafficChanged,
    required this.onAutoRenewalChanged,
  });

  final AppController controller;
  final bool busy;
  final ValueChanged<bool> onExpireChanged;
  final ValueChanged<bool> onTrafficChanged;
  final ValueChanged<bool> onAutoRenewalChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '账户偏好',
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _PreferenceRow(
            title: '到期提醒',
            subtitle: '套餐接近到期时提醒我',
            value: controller.user.remindExpire,
            onChanged: busy ? null : onExpireChanged,
          ),
          Divider(color: p.line, height: 1),
          _PreferenceRow(
            title: '流量提醒',
            subtitle: '剩余流量不足时提醒我',
            value: controller.user.remindTraffic,
            onChanged: busy ? null : onTrafficChanged,
          ),
          Divider(color: p.line, height: 1),
          _PreferenceRow(
            title: '自动续费',
            subtitle: '允许服务端在条件满足时自动续费',
            value: controller.user.autoRenewal,
            onChanged: busy ? null : onAutoRenewalChanged,
          ),
        ],
      ),
    );
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: p.inkMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({required this.onPassword, required this.onLogout});

  final VoidCallback onPassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.password_rounded,
              label: '修改密码',
              onTap: onPassword,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.logout_rounded,
              label: '退出登录',
              danger: true,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 18, color: danger ? p.danger : p.inkMuted),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: danger ? p.danger : p.ink,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _oldPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final oldPassword = _oldPassword.text;
    final newPassword = _newPassword.text;
    final confirmation = _confirmPassword.text;
    if (oldPassword.isEmpty || newPassword.isEmpty || confirmation.isEmpty) {
      setState(() => _error = '请完整填写密码');
      return;
    }
    if (newPassword != confirmation) {
      setState(() => _error = '两次输入的新密码不一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppScope.read(context).changePasswordApi(
        oldPassword: oldPassword,
        newPassword: newPassword,
        passwordConfirmation: confirmation,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('密码修改成功')));
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 430,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '修改账户密码',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PasswordField(controller: _oldPassword, label: '当前密码'),
            const SizedBox(height: 12),
            _PasswordField(controller: _newPassword, label: '新密码'),
            const SizedBox(height: 12),
            _PasswordField(controller: _confirmPassword, label: '确认新密码'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: p.dangerInk, fontSize: 11)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(_busy ? '正在提交…' : '保存新密码'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: p.surfaceRaised,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text()
    if old not in text:
        raise SystemExit(f'missing target in {path}: {old[:80]!r}')
    file.write_text(text.replace(old, new, 1))


def regex_once(path: str, pattern: str, replacement: str) -> None:
    file = Path(path)
    text = file.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'expected one regex match in {path}, got {count}: {pattern[:80]!r}')
    file.write_text(updated)


# Remote user: keep Telegram binding status from XiaoV2Board /user/info.
replace_once(
    'lib/shared/models/api_models.dart',
    "  final bool autoRenewal;\n\n  const RemoteUser({",
    "  final bool autoRenewal;\n  final String? telegramId;\n\n  const RemoteUser({",
)
replace_once(
    'lib/shared/models/api_models.dart',
    "    required this.autoRenewal,\n  });",
    "    required this.autoRenewal,\n    this.telegramId,\n  });",
)
replace_once(
    'lib/shared/models/api_models.dart',
    "      autoRenewal: _bool(json['auto_renewal']),\n    );",
    "      autoRenewal: _bool(json['auto_renewal']),\n      telegramId: _nullableIdentifier(json['telegram_id']),\n    );",
)
replace_once(
    'lib/shared/models/api_models.dart',
    "  static bool _bool(Object? value) {",
    "  static String? _nullableIdentifier(Object? value) {\n    if (value == null) return null;\n    final text = value.toString().trim();\n    if (text.isEmpty || text == '0' || text.toLowerCase() == 'null') {\n      return null;\n    }\n    return text;\n  }\n\n  static bool _bool(Object? value) {",
)

# XiaoV2Board account-service endpoints. These stay dormant on other panels.
replace_once(
    'lib/shared/services/panel_api.dart',
    "  Future<RemoteUser> getUserInfo({bool silent = false}) async {\n    final res = await _client.get('/user/info', silent: silent);\n    _check(res);\n    return RemoteUser.fromJson(_dataMap(res));\n  }\n\n  // ── Subscription / Nodes",
    "  Future<RemoteUser> getUserInfo({bool silent = false}) async {\n    final res = await _client.get('/user/info', silent: silent);\n    _check(res);\n    return RemoteUser.fromJson(_dataMap(res));\n  }\n\n  Future<void> redeemGiftCard(String giftCard) async {\n    final code = giftCard.trim();\n    if (code.isEmpty) throw const ApiException('兑换码不能为空');\n    final res = await _client.post(\n      '/user/redeemgiftcard',\n      data: {'giftcard': code},\n    );\n    _check(res);\n  }\n\n  Future<String> getTelegramBotUsername() async {\n    final res = await _client.get('/user/telegram/getBotInfo');\n    _check(res);\n    final username = _dataMap(res)['username']?.toString().trim() ?? '';\n    if (username.isEmpty) throw const ApiException('Telegram 机器人未配置');\n    return username.startsWith('@') ? username.substring(1) : username;\n  }\n\n  Future<void> unbindTelegram() async {\n    final res = await _client.get('/user/unbindTelegram');\n    _check(res);\n  }\n\n  // ── Subscription / Nodes",
)

# Desktop account imports for Xiao-only service UI and safe external opening.
replace_once(
    'lib/features/account/account_page.dart',
    "import 'dart:async';\n\nimport 'package:flutter/material.dart';",
    "import 'dart:async';\nimport 'dart:io';\n\nimport 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';",
)
replace_once(
    'lib/features/account/account_page.dart',
    "import '../../app/nav_destinations.dart';\n",
    "import '../../app/nav_destinations.dart';\nimport '../../config/app_config.dart';\nimport '../../config/panel_backend.dart';\n",
)
replace_once(
    'lib/features/account/account_page.dart',
    "import '../../shared/services/brand_asset_cache.dart';\n",
    "import '../../shared/services/brand_asset_cache.dart';\nimport '../../shared/services/windows_shell.dart';\n",
)

# Account-page actions for the new service modals.
replace_once(
    'lib/features/account/account_page.dart',
    "  void _showChangePasswordSheet() {\n    unawaited(showAccountChangePasswordModal(context));\n  }",
    "  void _showGiftCardModal() {\n    final ctrl = AppScope.of(context);\n    unawaited(\n      showAppAdaptiveModal<void>(\n        context: context,\n        builder: (_) => _GiftCardRedeemModal(ctrl: ctrl),\n      ),\n    );\n  }\n\n  void _showTelegramModal() {\n    final ctrl = AppScope.of(context);\n    unawaited(\n      showAppAdaptiveModal<void>(\n        context: context,\n        builder: (_) => _TelegramBindingModal(ctrl: ctrl),\n      ),\n    );\n  }\n\n  void _showChangePasswordSheet() {\n    unawaited(showAccountChangePasswordModal(context));\n  }",
)

# Desktop layout: top identity/subscription card stays; duplicate status cards go away.
replace_once(
    'lib/features/account/account_page.dart',
    "        _DesktopAccountMetrics(\n          ctrl: ctrl,\n          onRecharge: () => unawaited(showWalletRechargeModal(context)),\n          onTransfer: () => unawaited(showWalletTransferModal(context)),\n          onWithdraw: () => unawaited(showWalletWithdrawModal(context)),\n        ),\n        const SizedBox(height: 16),\n        _DesktopAccountServices(\n          onOrders: () => unawaited(showOrdersModal(context)),\n        ),",
    "        _DesktopFundsAccount(\n          ctrl: ctrl,\n          onRecharge: () => unawaited(showWalletRechargeModal(context)),\n          onTransfer: () => unawaited(showWalletTransferModal(context)),\n          onWithdraw: () => unawaited(showWalletWithdrawModal(context)),\n        ),\n        const SizedBox(height: 16),\n        _DesktopAccountServices(\n          showXiaoServices: AppConfig.panelType == PanelType.xiaoV2board,\n          telegramBound: ctrl.accountDetails?.telegramId != null,\n          onOrders: () => unawaited(showOrdersModal(context)),\n          onGiftCard: _showGiftCardModal,\n          onTelegram: _showTelegramModal,\n        ),",
)

# Insert account-service modals before desktop widget definitions.
replace_once(
    'lib/features/account/account_page.dart',
    "// ── Desktop account widgets ──────────────────────────────────────────────\n",
    r'''Future<bool> _openExternalHttps(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    if (Platform.isWindows) return shellExecuteUrl(url);
    if (Platform.isMacOS) {
      return (await Process.run('open', [url])).exitCode == 0;
    }
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [url])).exitCode == 0;
    }
  } catch (_) {
    return false;
  }
  return false;
}

class _GiftCardRedeemModal extends StatefulWidget {
  const _GiftCardRedeemModal({required this.ctrl});

  final AppController ctrl;

  @override
  State<_GiftCardRedeemModal> createState() => _GiftCardRedeemModalState();
}

class _GiftCardRedeemModalState extends State<_GiftCardRedeemModal> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty || _submitting) {
      if (code.isEmpty) setState(() => _error = _accountText(context, hans: '请输入兑换码', hant: '請輸入兌換碼', en: 'Enter a redemption code'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.ctrl.api.redeemGiftCard(code);
      await widget.ctrl.refreshData();
      if (!mounted) return;
      AppToast.show(
        context,
        _accountText(context, hans: '兑换成功', hant: '兌換成功', en: 'Redeemed successfully'),
        type: AppToastType.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: _accountText(context, hans: '兑换码', hant: '兌換碼', en: 'Redemption code'),
      subtitle: _accountText(
        context,
        hans: '兑换余额、流量、时长或套餐权益',
        hant: '兌換餘額、流量、時長或套餐權益',
        en: 'Redeem account or plan benefits',
      ),
      maxWidth: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _controller,
            label: _accountText(context, hans: '兑换码', hant: '兌換碼', en: 'Code'),
            hint: _accountText(context, hans: '请输入兑换码', hant: '請輸入兌換碼', en: 'Enter code'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: AppTextStyles.caption.copyWith(color: c.danger),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 42,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(
                _submitting
                    ? _accountText(context, hans: '兑换中…', hant: '兌換中…', en: 'Redeeming…')
                    : _accountText(context, hans: '立即兑换', hant: '立即兌換', en: 'Redeem now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TelegramBindingModal extends StatefulWidget {
  const _TelegramBindingModal({required this.ctrl});

  final AppController ctrl;

  @override
  State<_TelegramBindingModal> createState() => _TelegramBindingModalState();
}

class _TelegramBindingModalState extends State<_TelegramBindingModal> {
  String _botUsername = '';
  String? _error;
  bool _loading = true;
  bool _working = false;

  bool get _bound => widget.ctrl.accountDetails?.telegramId != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBot());
  }

  Future<void> _loadBot() async {
    try {
      final username = await widget.ctrl.api.getTelegramBotUsername();
      if (!mounted) return;
      setState(() {
        _botUsername = username;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  Future<void> _copyBindCommand() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final subscribeUrl = await widget.ctrl.api.getSubscribeUrl();
      await Clipboard.setData(ClipboardData(text: '/bind $subscribeUrl'));
      if (!mounted) return;
      AppToast.show(
        context,
        _accountText(context, hans: '绑定命令已复制', hant: '綁定指令已複製', en: 'Binding command copied'),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _openTelegram() async {
    if (_botUsername.isEmpty) return;
    final opened = await _openExternalHttps('https://t.me/$_botUsername');
    if (!mounted || opened) return;
    setState(() {
      _error = _accountText(
        context,
        hans: '无法打开 Telegram，请手动搜索 @$_botUsername',
        hant: '無法開啟 Telegram，請手動搜尋 @$_botUsername',
        en: 'Could not open Telegram. Search for @$_botUsername manually.',
      );
    });
  }

  Future<void> _refreshStatus() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.ctrl.refreshData();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _unbind() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.ctrl.api.unbindTelegram();
      await widget.ctrl.refreshData();
      if (!mounted) return;
      setState(() {});
      AppToast.show(
        context,
        _accountText(context, hans: 'Telegram 已解绑', hant: 'Telegram 已解除綁定', en: 'Telegram unbound'),
        type: AppToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final status = _bound
        ? _accountText(context, hans: '已绑定', hant: '已綁定', en: 'Connected')
        : _accountText(context, hans: '未绑定', hant: '未綁定', en: 'Not connected');
    return AppAdaptiveModal(
      title: 'Telegram',
      subtitle: _accountText(
        context,
        hans: '绑定后可接收到期、流量和服务通知',
        hant: '綁定後可接收到期、流量和服務通知',
        en: 'Connect Telegram for account notifications',
      ),
      maxWidth: 540,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.softBorder),
            ),
            child: Row(
              children: [
                _SmallIcon(icon: LucideIcons.send, color: c.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _loading
                            ? _accountText(context, hans: '正在读取机器人…', hant: '正在讀取機器人…', en: 'Loading bot…')
                            : _botUsername.isEmpty
                                ? 'Telegram Bot'
                                : '@$_botUsername',
                        style: AppTextStyles.bodyStrong,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        status,
                        style: AppTextStyles.caption.copyWith(
                          color: _bound ? c.success : c.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 16),
          if (_bound)
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _working ? null : _unbind,
                child: Text(_accountText(context, hans: '解除绑定', hant: '解除綁定', en: 'Unbind Telegram')),
              ),
            )
          else ...[
            Text(
              _accountText(
                context,
                hans: '先复制绑定命令，再打开机器人并粘贴发送。订阅地址不会显示在账户页面。',
                hant: '先複製綁定指令，再開啟機器人並貼上傳送。訂閱地址不會顯示在帳戶頁面。',
                en: 'Copy the binding command, open the bot, then paste and send it.',
              ),
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _working || _loading ? null : _copyBindCommand,
                      child: Text(_accountText(context, hans: '复制绑定命令', hant: '複製綁定指令', en: 'Copy command')),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _loading || _botUsername.isEmpty ? null : _openTelegram,
                      child: Text(_accountText(context, hans: '打开 Telegram', hant: '開啟 Telegram', en: 'Open Telegram')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _working ? null : _refreshStatus,
              child: Text(_accountText(context, hans: '我已完成绑定，刷新状态', hant: '我已完成綁定，重新整理狀態', en: 'I finished binding — refresh status')),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Desktop account widgets ──────────────────────────────────────────────
''',
)

# Replace the duplicate plan/balance/expiry metric strip with one coherent funds account.
regex_once(
    'lib/features/account/account_page.dart',
    r'class _DesktopAccountMetrics extends StatelessWidget \{.*?\nclass _DesktopAccountServices extends StatelessWidget \{',
    r'''class _DesktopFundsAccount extends StatelessWidget {
  const _DesktopFundsAccount({
    required this.ctrl,
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final AppController ctrl;
  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final balance = ctrl.user.balance / 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopFundsLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(14),
          shadow: AppCardShadow.soft,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DesktopFundValue(
                      icon: LucideIcons.wallet,
                      label: context.l10n.accountBalance,
                      value: '${ctrl.currencySymbol}${balance.toStringAsFixed(2)}',
                    ),
                  ),
                  Container(width: 1, height: 44, color: c.softBorder),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _DesktopFundValue(
                      icon: LucideIcons.badgeDollarSign,
                      label: context.l10n.withdrawableCommission,
                      value: '${ctrl.currencySymbol}${ctrl.withdrawable.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Divider(color: c.softBorder),
              const SizedBox(height: 10),
              _DesktopMoneyActions(
                onRecharge: onRecharge,
                onTransfer: onTransfer,
                onWithdraw: onWithdraw,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopFundValue extends StatelessWidget {
  const _DesktopFundValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      children: [
        _SmallIcon(icon: icon, color: c.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption.copyWith(color: c.textMuted)),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: c.textPrimary,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopMoneyActions extends StatelessWidget {
  const _DesktopMoneyActions({
    required this.onRecharge,
    required this.onTransfer,
    required this.onWithdraw,
  });

  final VoidCallback onRecharge;
  final VoidCallback onTransfer;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DesktopMoneyAction(
            label: context.l10n.rechargeBalance,
            onTap: onRecharge,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DesktopMoneyAction(
            label: _accountText(context, hans: '划转佣金', hant: '劃轉佣金', en: 'Transfer commission'),
            onTap: onTransfer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DesktopMoneyAction(
            label: _accountText(context, hans: '申请提现', hant: '申請提現', en: 'Request withdrawal'),
            onTap: onWithdraw,
          ),
        ),
      ],
    );
  }
}

class _DesktopMoneyAction extends StatelessWidget {
  const _DesktopMoneyAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.16)),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: c.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopAccountServices extends StatelessWidget {''',
)

# Expand desktop services: orders + gift-card + Telegram binding.
regex_once(
    'lib/features/account/account_page.dart',
    r'class _DesktopAccountServices extends StatelessWidget \{.*?\nclass _DesktopAccountSettings extends StatelessWidget \{',
    r'''class _DesktopAccountServices extends StatelessWidget {
  const _DesktopAccountServices({
    required this.showXiaoServices,
    required this.telegramBound,
    required this.onOrders,
    required this.onGiftCard,
    required this.onTelegram,
  });

  final bool showXiaoServices;
  final bool telegramBound;
  final VoidCallback onOrders;
  final VoidCallback onGiftCard;
  final VoidCallback onTelegram;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final showOrders = isPageEnabled(AppPage.orders);
    if (!showOrders && !showXiaoServices) return const SizedBox.shrink();

    final rows = <Widget>[];
    void addRow(Widget row) {
      if (rows.isNotEmpty) rows.add(_Divider(color: c.softBorder));
      rows.add(row);
    }

    if (showOrders) {
      addRow(
        _ActionRow(
          icon: LucideIcons.clipboardList,
          title: desktopPageLabel(context, AppPage.orders),
          subtitle: context.l10n.ordersSubtitle,
          onTap: onOrders,
        ),
      );
    }
    if (showXiaoServices) {
      addRow(
        _ActionRow(
          icon: LucideIcons.ticketCheck,
          title: _accountText(context, hans: '兑换码', hant: '兌換碼', en: 'Redemption code'),
          subtitle: _accountText(
            context,
            hans: '兑换余额、流量或套餐权益',
            hant: '兌換餘額、流量或套餐權益',
            en: 'Redeem account or plan benefits',
          ),
          onTap: onGiftCard,
        ),
      );
      addRow(
        _ActionRow(
          icon: LucideIcons.send,
          title: 'Telegram',
          subtitle: telegramBound
              ? _accountText(context, hans: '已绑定，可接收账户通知', hant: '已綁定，可接收帳戶通知', en: 'Connected for account notifications')
              : _accountText(context, hans: '未绑定，点击连接 Telegram', hant: '未綁定，點擊連接 Telegram', en: 'Not connected — connect Telegram'),
          onTap: onTelegram,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _desktopAccountServicesLabel(context),
          style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shadow: AppCardShadow.soft,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _DesktopAccountSettings extends StatelessWidget {''',
)

# Desktop account copy helpers.
regex_once(
    'lib/features/account/account_page.dart',
    r"String _desktopAccountServicesLabel\(BuildContext context\) \{.*?\n\}\n\nString _desktopAccountSettingsLabel\(BuildContext context\) \{.*?\n\}\n",
    r'''String _accountText(
  BuildContext context, {
  required String hans,
  required String hant,
  required String en,
}) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode != 'zh') return en;
  final traditional =
      locale.scriptCode == 'Hant' ||
      locale.countryCode == 'TW' ||
      locale.countryCode == 'HK' ||
      locale.countryCode == 'MO';
  return traditional ? hant : hans;
}

String _desktopFundsLabel(BuildContext context) => _accountText(
  context,
  hans: '资金账户',
  hant: '資金帳戶',
  en: 'Funds account',
);

String _desktopAccountServicesLabel(BuildContext context) => _accountText(
  context,
  hans: '账户服务',
  hant: '帳戶服務',
  en: 'Account services',
);

String _desktopAccountSettingsLabel(BuildContext context) => _accountText(
  context,
  hans: '账户设置',
  hant: '帳戶設定',
  en: 'Account settings',
);
''',
)

# Regression coverage for the new account-service data and UI contracts.
Path('test/account_center_services_test.dart').write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litchi_client/shared/models/api_models.dart';

void main() {
  test('RemoteUser keeps XiaoV2Board Telegram binding state', () {
    final bound = RemoteUser.fromJson({'email': '191066639@example.com', 'telegram_id': 123456789});
    final unbound = RemoteUser.fromJson({'email': '191066639@example.com', 'telegram_id': null});

    expect(bound.telegramId, '123456789');
    expect(unbound.telegramId, isNull);
  });

  test('desktop account uses one funds section instead of duplicate status cards', () {
    final source = File('lib/features/account/account_page.dart').readAsStringSync();

    expect(source, contains('class _DesktopFundsAccount'));
    expect(source, isNot(contains('class _DesktopAccountMetrics')));
    expect(source, contains("hans: '划转佣金'"));
    expect(source, contains("hans: '申请提现'"));
    expect(source, contains('class _GiftCardRedeemModal'));
    expect(source, contains('class _TelegramBindingModal'));
  });

  test('panel API keeps XiaoV2Board gift card and Telegram endpoints', () {
    final source = File('lib/shared/services/panel_api.dart').readAsStringSync();

    expect(source, contains("'/user/redeemgiftcard'"));
    expect(source, contains("'/user/telegram/getBotInfo'"));
    expect(source, contains("'/user/unbindTelegram'"));
  });
}
''')

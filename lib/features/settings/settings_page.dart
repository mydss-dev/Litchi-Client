import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/config/app_config.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_select.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/page_header.dart';

/// Settings page (§15): General / Network / Advanced cards.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _coreVersion = '加载中…';
  bool _restarting = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    AppController.getCoreVersion().then((v) {
      if (mounted) setState(() => _coreVersion = v);
    });
  }

  Future<void> _onRestart() async {
    setState(() => _restarting = true);
    final error = await AppScope.of(context).restartCore();
    if (!mounted) return;
    setState(() => _restarting = false);
    if (error != null) {
      AppToast.show(context, error, type: AppToastType.error);
    } else {
      AppToast.show(context, '核心已重启', type: AppToastType.success);
    }
  }

  Future<void> _onFixProxy() async {
    await AppScope.of(context).fixProxy();
    if (!mounted) return;
    AppToast.show(context, '代理设置已同步', type: AppToastType.success);
  }

  Future<void> _onExportLogs() async {
    setState(() => _exporting = true);
    final path = await AppScope.of(context).exportLogs();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (path != null) {
      AppToast.show(context, '日志已保存至 $path', type: AppToastType.success);
    } else {
      AppToast.show(context, '暂无日志，请先连接后再导出', type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(title: '设置', subtitle: '配置客户端偏好和网络选项'),
          const SizedBox(height: 12),
          if (!AppConfig.isSecureServer) ...[
            const _HttpsWarningCard(),
            const SizedBox(height: 12),
          ],
          // ── System ─────────────────────────────────────────────────────────
          _SettingsGroup(
            title: '系统设置',
            children: [
              _SettingRow(
                label: '开机启动',
                trailing: AppSwitch(
                  value: ctrl.autoStart,
                  onChanged: ctrl.setAutoStart,
                ),
              ),
              _SettingRow(
                label: '自动更新',
                trailing: AppSwitch(
                  value: ctrl.autoUpdate,
                  onChanged: ctrl.setAutoUpdate,
                ),
              ),
              _SettingRow(
                label: '外观模式',
                trailing: AppSelect<ThemeMode>(
                  value: ctrl.themeMode,
                  items: const [
                    ThemeMode.system,
                    ThemeMode.light,
                    ThemeMode.dark,
                  ],
                  labelOf: (v) => switch (v) {
                    ThemeMode.system => '跟随系统',
                    ThemeMode.light => '浅色模式',
                    ThemeMode.dark => '深色模式',
                  },
                  onChanged: ctrl.setThemeMode,
                ),
              ),
              _SettingRow(
                label: '语言',
                trailing: AppSelect<String>(
                  value: ctrl.language,
                  items: const ['简体中文', 'English', '繁體中文'],
                  labelOf: (v) => v,
                  onChanged: ctrl.setLanguage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Connection ─────────────────────────────────────────────────────
          _SettingsGroup(
            title: '连接设置',
            children: [
              _SettingRow(
                label: '代理模式',
                trailing: AppSelect<ProxyMode>(
                  value: ctrl.proxyMode,
                  items: ProxyMode.values,
                  labelOf: (v) => v.label,
                  onChanged: ctrl.setProxyMode,
                ),
              ),
              _SettingRow(
                label: 'DNS',
                trailing: AppSelect<String>(
                  value: ctrl.dnsMode,
                  items: const ['系统 DNS', 'Cloudflare', 'Google'],
                  labelOf: (v) => v,
                  onChanged: ctrl.setDnsMode,
                ),
              ),
              _PortSettingRow(controller: ctrl),
            ],
          ),
          const SizedBox(height: 16),
          // ── Diagnostics ────────────────────────────────────────────────────
          _SettingsGroup(
            title: '核心与诊断',
            children: [
              _SettingRow(
                label: '开发者模式',
                trailing: AppSwitch(
                  value: ctrl.devMode,
                  onChanged: ctrl.setDevMode,
                ),
              ),
              _SettingRow(
                label: '核心版本',
                trailing: Text(
                  _coreVersion,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.of(context).textMuted,
                  ),
                ),
              ),
              _SettingRow(
                label: '重启核心',
                trailing: _DiagnosticButton(
                  label: _restarting ? '重启中…' : '重启',
                  enabled: ctrl.coreRunning && !_restarting,
                  onTap: _onRestart,
                ),
              ),
              _SettingRow(
                label: '修复系统代理',
                trailing: _DiagnosticButton(label: '修复', onTap: _onFixProxy),
              ),
              _SettingRow(
                label: '导出诊断日志',
                trailing: _DiagnosticButton(
                  label: _exporting ? '导出中…' : '导出',
                  enabled: !_exporting,
                  onTap: _onExportLogs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Support ────────────────────────────────────────────────────────
          if (AppConfig.supportUrl.isNotEmpty) ...[
            _SettingsGroup(
              title: '帮助与关于',
              children: [
                _SettingRow(
                  label: '联系客服',
                  trailing: _DiagnosticButton(
                    label: '打开',
                    onTap: () => _openUrl(AppConfig.supportUrl),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // ── Account ────────────────────────────────────────────────────────
          _SettingsGroup(
            title: '账号安全',
            children: [_LogoutRow(onLogout: ctrl.logout)],
          ),
        ],
      ),
    );
  }
}

void _openUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return;
  Process.run('explorer', [url]);
}

class _HttpsWarningCard extends StatelessWidget {
  const _HttpsWarningCard();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 15, color: c.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '当前服务器使用 HTTP 连接，数据传输未加密，存在中间人攻击风险。'
              '建议联系服务商开启 HTTPS。',
              style: AppTextStyles.caption.copyWith(
                color: c.warning,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.onLogout});

  final VoidCallback onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder: (_) => const _LogoutConfirmDialog(),
    );
    if (confirmed == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '退出登录',
              style: AppTextStyles.body.copyWith(color: c.danger),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _confirmLogout(context),
              child: Icon(LucideIcons.logOut, size: 18, color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutConfirmDialog extends StatelessWidget {
  const _LogoutConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: c.softBorder),
            boxShadow: AppShadows.card(c),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.dangerSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(LucideIcons.logOut, size: 19, color: c.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '退出登录',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: c.textPrimary,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '退出后会断开当前代理连接，并清除本次登录状态。',
                style: AppTextStyles.body.copyWith(
                  color: c.textSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogTextButton(
                    label: '取消',
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  _DialogDangerButton(
                    label: '退出登录',
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogTextButton extends StatelessWidget {
  const _DialogTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: c.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _DialogDangerButton extends StatelessWidget {
  const _DialogDangerButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.danger,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.sectionTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(color: c.softBorder, height: 1),
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// Small action button used inside diagnostic setting rows.
class _DiagnosticButton extends StatelessWidget {
  const _DiagnosticButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? c.primarySoft : c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: enabled ? c.primary.withValues(alpha: 0.3) : c.softBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: enabled ? c.primary : c.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Port number input row — edits AppController.proxyPort.
class _PortSettingRow extends StatefulWidget {
  const _PortSettingRow({required this.controller});
  final AppController controller;

  @override
  State<_PortSettingRow> createState() => _PortSettingRowState();
}

class _PortSettingRowState extends State<_PortSettingRow> {
  late final TextEditingController _ctrl;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.controller.proxyPort.toString());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_ctrl.text.trim());
    if (v == null || v < 1 || v > 65535) {
      setState(() => _hasError = true);
      _ctrl.text = widget.controller.proxyPort.toString();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _hasError = false);
      });
      return;
    }
    setState(() => _hasError = false);
    widget.controller.setProxyPort(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '代理端口',
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                ),
                Text(
                  'HTTP + SOCKS5  127.0.0.1:${widget.controller.proxyPort}',
                  style: AppTextStyles.caption.copyWith(
                    color: c.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 34,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onEditingComplete: _commit,
              onTapOutside: (_) => _commit(),
              style: AppTextStyles.body.copyWith(
                color: _hasError ? c.danger : c.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: _hasError ? c.danger : c.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: c.primary),
                ),
                filled: true,
                fillColor: c.cardBg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../../app/nav_destinations.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/services/secure_logger.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_select.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/responsive_page_scaffold.dart';

/// Settings page (§15): General / Network / Advanced cards.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _coreVersion = '获取中…';

  @override
  void initState() {
    super.initState();
    AppController.getCoreVersion().then((version) {
      if (mounted) setState(() => _coreVersion = version);
    });
  }

  Future<void> _onFixProxy() async {
    await AppScope.of(context).fixProxy();
    if (!mounted) return;
    AppToast.show(context, '网络设置已修复', type: AppToastType.success);
  }

  void _showDiagnosticInfo() {
    final ctrl = AppScope.of(context);
    final logs = ctrl.coreLogs
        .map(SecureLogRedactor.redact)
        .where((line) => line.isNotEmpty)
        .toList();
    final status = ctrl.coreConnecting
        ? '连接处理中'
        : ctrl.coreRunning
        ? '已连接'
        : '未连接';
    final text = [
      '${AppConfig.appName} ${AppConfig.currentVersion}',
      '平台：${Platform.operatingSystem}',
      '连接状态：$status',
      '记录时间：${DateTime.now().toLocal()}',
      if (ctrl.coreError.isNotEmpty)
        '最近错误：${SecureLogRedactor.redact(ctrl.coreError)}',
      '',
      if (logs.isEmpty) '暂无运行日志，请先尝试连接后再查看。' else ...logs,
    ].join('\n');

    showAppBottomSheet<void>(
      context: context,
      builder: (_) => _DiagnosticInfoSheet(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePageScaffold(
      title: '设置',
      subtitle: '配置客户端偏好和网络选项',
      compactTitle: '设置',
      primaryCompact: isPrimaryCompactTab(AppPage.settings),
      onBack: () => AppScope.of(context).goToPage(AppPage.account),
      compactBodySpacing: 18,
      showWideBack: false,
      children: _bodyChildren(context),
    );
  }

  // ── Shared body (all settings sections) ────────────────────────────────────

  List<Widget> _bodyChildren(BuildContext context) {
    final ctrl = AppScope.of(context);
    final supportsSystemProxy = Platform.isWindows || Platform.isMacOS;

    return [
      if (!AppConfig.isSecureServer) ...[
        const _HttpsWarningCard(),
        const SizedBox(height: 12),
      ],
      _SettingsGroup(
        title: '系统设置',
        children: [
          if (Platform.isWindows)
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
              items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
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
        ],
      ),
      const SizedBox(height: 16),
      if (supportsSystemProxy) ...[
        _SettingsGroup(
          title: '安全设置',
          children: [
            _SettingRow(
              label: '连接中断保护',
              subtitle: '连接意外中断时阻止网络直接访问，避免隐私泄漏',
              trailing: AppSwitch(
                value: ctrl.killSwitch,
                onChanged: ctrl.setKillSwitch,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
      _AdvancedSettingsGroup(
        enabled: ctrl.devMode,
        onChanged: ctrl.setDevMode,
        children: [
          if (supportsSystemProxy)
            _SettingRow(
              label: '修复网络设置',
              subtitle: '连接异常或断开后无法上网时尝试修复',
              trailing: _DiagnosticButton(label: '修复', onTap: _onFixProxy),
            ),
          _SettingRow(
            label: '诊断信息',
            subtitle: '查看并复制信息，发送给管理员或客服',
            trailing: _DiagnosticButton(
              label: '查看',
              onTap: _showDiagnosticInfo,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _SettingsGroup(
        title: '关于应用',
        children: [
          _SettingRow(
            label: '应用版本',
            trailing: Text(
              AppConfig.currentVersion,
              style: AppTextStyles.body.copyWith(
                color: AppColors.of(context).textMuted,
              ),
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
        ],
      ),
    ];
  }
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
              '当前服务器使用 HTTP 连接，数据传输未加密，存在中间人攻击风险。建议联系服务商开启 HTTPS。',
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

class _AdvancedSettingsGroup extends StatelessWidget {
  const _AdvancedSettingsGroup({
    required this.enabled,
    required this.onChanged,
    required this.children,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppCard(
      radius: AppRadius.lg,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '高级设置',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '开启后显示网络修复与诊断功能',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSwitch(value: enabled, onChanged: onChanged),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: enabled
                ? Column(
                    children: [
                      Divider(color: c.softBorder, height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < children.length;
                              index++
                            ) ...[
                              children[index],
                              if (index != children.length - 1)
                                Divider(color: c.softBorder, height: 1),
                            ],
                          ],
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.label,
    required this.trailing,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: subtitle != null ? 68 : 46,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: c.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textSecondary,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _DiagnosticButton extends StatelessWidget {
  const _DiagnosticButton({required this.label, required this.onTap});

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
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.3)),
          ),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(
              color: c.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticInfoSheet extends StatelessWidget {
  const _DiagnosticInfoSheet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: '诊断信息',
      subtitle: '复制后发送给管理员或客服，可帮助快速定位问题',
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.softBorder),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 11,
                height: 1.5,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              AppToast.show(
                context,
                '诊断信息已复制，请发送给管理员或客服',
                type: AppToastType.success,
              );
            },
            icon: const Icon(LucideIcons.copy, size: 17),
            label: const Text('一键复制'),
          ),
        ),
      ],
    );
  }
}

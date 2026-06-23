import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart' show ProxyMode;
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_switch.dart';
import '../../shared/widgets/app_toast.dart';
import 'mobile_back_button.dart';

class MobileSettingsPage extends StatefulWidget {
  const MobileSettingsPage({super.key});

  @override
  State<MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<MobileSettingsPage> {
  String _versionText = '读取中';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _versionText = '${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            MobileBackButton(onTap: () => ctrl.goToPage(AppPage.account)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '系统设置',
                style: AppTextStyles.pageTitle.copyWith(
                  color: c.textPrimary,
                  fontSize: 26,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionLabel('外观'),
        const SizedBox(height: 8),
        _SettingsSection(
          children: [
            _SwitchRow(
              icon: LucideIcons.moon,
              title: '深色模式',
              subtitle: '切换应用外观',
              value: ctrl.isDark,
              onChanged: ctrl.toggleDarkMode,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('连接'),
        const SizedBox(height: 8),
        _SettingsSection(
          children: [
            _OptionRow(
              icon: LucideIcons.route,
              title: '代理模式',
              subtitle: '控制流量分流方式',
              value: _proxyModeLabel(ctrl.proxyMode),
              onTap: () => _pickProxyMode(context),
            ),
            _Divider(color: c.softBorder),
            _OptionRow(
              icon: LucideIcons.globe,
              title: 'DNS',
              subtitle: '解析异常时可切换',
              value: _dnsModeLabel(ctrl.dnsMode),
              onTap: () => _pickDnsMode(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('高级'),
        const SizedBox(height: 8),
        _SettingsSection(
          children: [
            _InfoRow(
              icon: LucideIcons.badgeInfo,
              title: '当前版本',
              subtitle: '应用安装版本',
              value: _versionText,
            ),
            _Divider(color: c.softBorder),
            _OptionRow(
              icon: LucideIcons.settings2,
              title: '高级设置',
              subtitle: '调试信息',
              value: '配置',
              onTap: () => _showAdvancedSettings(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickProxyMode(BuildContext context) async {
    final ctrl = AppScope.of(context);
    final mode = await showAppBottomSheet<ProxyMode>(
      context: context,
      builder: (context) => _PickerSheet<ProxyMode>(
        title: '代理模式',
        selected: ctrl.proxyMode,
        items: const [
          _PickerItem(ProxyMode.rule, '规则模式', '按规则分流，日常推荐'),
          _PickerItem(ProxyMode.global, '全局模式', '全部流量走代理'),
          _PickerItem(ProxyMode.direct, '直连模式', '不经过代理节点'),
        ],
      ),
    );
    if (mode != null && mode != ctrl.proxyMode) {
      ctrl.setProxyMode(mode);
      if (!context.mounted) return;
      AppToast.show(context, mode.switchToast, type: AppToastType.success);
    }
  }

  Future<void> _pickDnsMode(BuildContext context) async {
    final ctrl = AppScope.of(context);
    final mode = await showAppBottomSheet<String>(
      context: context,
      builder: (context) => _PickerSheet<String>(
        title: 'DNS',
        selected: ctrl.dnsMode,
        items: const [
          _PickerItem('系统 DNS', '系统 DNS', '默认解析策略，优先推荐'),
          _PickerItem('Cloudflare', 'Cloudflare', '海外解析更快'),
          _PickerItem('Google', 'Google', '备用公共 DNS'),
        ],
      ),
    );
    if (mode != null) ctrl.setDnsMode(mode);
  }

  Future<void> _showAdvancedSettings(BuildContext context) async {
    final ctrl = AppScope.of(context);
    await showAppBottomSheet<void>(
      context: context,
      builder: (context) => AnimatedBuilder(
        animation: ctrl,
        builder: (context, _) => AppBottomSheet(
          title: '高级设置',
          subtitle: '一般不用改，连接异常或调试时再调整',
          children: [
            _SwitchRow(
              icon: LucideIcons.code2,
              title: '开发者模式',
              subtitle: '显示调试与高级信息',
              value: ctrl.devMode,
              onChanged: ctrl.setDevMode,
            ),
          ],
        ),
      ),
    );
  }
}

String _proxyModeLabel(ProxyMode mode) => switch (mode) {
  ProxyMode.rule => '规则',
  ProxyMode.global => '全局',
  ProxyMode.direct => '直连',
};

String _dnsModeLabel(String mode) => switch (mode) {
  'Cloudflare' => 'Cloudflare',
  'Google' => 'Google',
  _ => '系统 DNS',
};

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _LeadingIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: c.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
        boxShadow: AppShadows.soft(c),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          _LeadingIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          AppSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _LeadingIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(width: 8),
              Icon(LucideIcons.chevronRight, color: c.iconMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: c.primary, size: 18),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 62, color: color);
  }
}

class _PickerItem<T> {
  const _PickerItem(this.value, this.title, this.subtitle);

  final T value;
  final String title;
  final String subtitle;
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.selected,
    required this.items,
  });

  final String title;
  final T selected;
  final List<_PickerItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppBottomSheet(
      title: title,
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title, style: AppTextStyles.bodyStrong),
            subtitle: Text(
              item.subtitle,
              style: AppTextStyles.caption.copyWith(color: c.textMuted),
            ),
            trailing: item.value == selected
                ? Icon(LucideIcons.circleCheck, color: c.primary, size: 20)
                : null,
            onTap: () => Navigator.of(context).pop(item.value),
          ),
      ],
    );
  }
}

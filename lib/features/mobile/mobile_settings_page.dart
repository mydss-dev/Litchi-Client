import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text(
          '设置',
          style: AppTextStyles.pageTitle.copyWith(
            color: c.textPrimary,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '应用外观与连接偏好',
          style: AppTextStyles.caption.copyWith(color: c.textMuted),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          children: [
            _SwitchRow(
              icon: LucideIcons.moon,
              title: '深色模式',
              subtitle: '切换应用外观',
              value: ctrl.isDark,
              onChanged: ctrl.toggleDarkMode,
            ),
            _Divider(color: c.softBorder),
            _SwitchRow(
              icon: LucideIcons.code2,
              title: '开发者模式',
              subtitle: '显示调试与高级信息',
              value: ctrl.devMode,
              onChanged: ctrl.setDevMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          children: [
            _OptionRow(
              icon: LucideIcons.route,
              title: '代理模式',
              value: ctrl.proxyMode.label,
              onTap: () => _pickProxyMode(context),
            ),
            _Divider(color: c.softBorder),
            _OptionRow(
              icon: LucideIcons.network,
              title: '网络模式',
              value: ctrl.networkMode.label,
              onTap: () => _pickNetworkMode(context),
            ),
            _Divider(color: c.softBorder),
            _OptionRow(
              icon: LucideIcons.server,
              title: '本地端口',
              value: ctrl.proxyPort.toString(),
              onTap: () => _editPort(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickProxyMode(BuildContext context) async {
    final ctrl = AppScope.of(context);
    final mode = await showModalBottomSheet<ProxyMode>(
      context: context,
      builder: (context) => _PickerSheet<ProxyMode>(
        title: '代理模式',
        selected: ctrl.proxyMode,
        items: const [
          _PickerItem(ProxyMode.rule, '规则模式', '按规则分流常用网站'),
          _PickerItem(ProxyMode.global, '全局模式', '所有流量走代理'),
          _PickerItem(ProxyMode.direct, '直连模式', '不经过代理节点'),
        ],
      ),
    );
    if (mode != null) ctrl.setProxyMode(mode);
  }

  Future<void> _pickNetworkMode(BuildContext context) async {
    final ctrl = AppScope.of(context);
    final mode = await showModalBottomSheet<NetworkMode>(
      context: context,
      builder: (context) => _PickerSheet<NetworkMode>(
        title: '网络模式',
        selected: ctrl.networkMode,
        items: const [
          _PickerItem(NetworkMode.system, '系统代理', '轻量连接，适合浏览器和常规应用'),
          _PickerItem(NetworkMode.tun, '虚拟网卡', '接管更多应用流量'),
        ],
      ),
    );
    if (mode != null) ctrl.setNetworkMode(mode);
  }

  Future<void> _editPort(BuildContext context) async {
    final ctrl = AppScope.of(context);
    final textCtrl = TextEditingController(text: ctrl.proxyPort.toString());
    final port = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final c = AppColors.of(context);
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 18,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本地端口',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(hintText: '7890'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final value = int.tryParse(textCtrl.text.trim());
                    if (value == null || value < 1024 || value > 65535) {
                      return;
                    }
                    Navigator.of(context).pop(value);
                  },
                  style: FilledButton.styleFrom(backgroundColor: c.primary),
                  child: const Text('保存'),
                ),
              ),
            ],
          ),
        );
      },
    );
    textCtrl.dispose();
    if (port != null) await ctrl.setProxyPort(port);
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
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
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
                child: Text(
                  title,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
              ),
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
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
        ),
      ),
    );
  }
}

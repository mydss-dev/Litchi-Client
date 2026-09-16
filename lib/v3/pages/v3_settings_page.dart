import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3SettingsPage extends StatefulWidget {
  const V3SettingsPage({super.key});

  @override
  State<V3SettingsPage> createState() => _V3SettingsPageState();
}

class _V3SettingsPageState extends State<V3SettingsPage> {
  bool _busy = false;
  bool _failed = false;
  String? _message;

  Future<void> _apply(Future<String?> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = '正在应用设置，请稍候…';
      _failed = false;
    });
    try {
      final error = await action();
      if (mounted) {
        setState(() {
          _failed = error != null;
          _message = error == null ? success : '$error。请重试或重新连接。';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = '设置未能完成，请重试或重新连接。';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const V3PageHeader(
            kicker: '偏好与诊断',
            title: '设置',
            description: '管理网络连接、启动方式与外观。',
          ),
          const SizedBox(height: 20),
          if (_message != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                _message!,
                style: TextStyle(
                  color: _failed ? p.dangerInk : p.inkMuted,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
          ],
          AbsorbPointer(
            absorbing: _busy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const V3SectionLabel('网络'),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingRow(
                        index: '01',
                        title: '代理接管方式',
                        description: '系统代理用于支持代理的应用；TUN 接管设备流量，可能需要管理员权限。',
                        control: _Segment<NetworkMode>(
                          value: controller.networkMode,
                          items: const [NetworkMode.system, NetworkMode.tun],
                          label: (v) =>
                              v == NetworkMode.system ? '系统代理' : 'TUN',
                          onChanged: (v) => _apply(
                            () => controller.setNetworkMode(v),
                            controller.coreProcessRunning
                                ? '网络配置已应用'
                                : '设置已保存，将在连接时使用',
                          ),
                        ),
                      ),
                      _SettingRow(
                        index: '02',
                        title: 'DNS 解析',
                        description: '使用系统 DNS，或选择其他解析服务。',
                        control: _Segment<DnsMode>(
                          value: controller.dnsMode,
                          items: const [
                            DnsMode.system,
                            DnsMode.cloudflare,
                            DnsMode.google,
                          ],
                          label: (v) => switch (v) {
                            DnsMode.system => '系统',
                            DnsMode.cloudflare => 'Cloudflare',
                            DnsMode.google => 'Google',
                          },
                          onChanged: (v) => _apply(
                            () => controller.setDnsMode(v),
                            controller.coreProcessRunning
                                ? 'DNS 配置已应用'
                                : '设置已保存，将在连接时使用',
                          ),
                        ),
                      ),
                      _SettingRow(
                        index: '03',
                        title: '断线保护',
                        description: '连接意外中断时限制流量；是否可用取决于平台和网络模式。',
                        last: true,
                        control: _V3Switch(
                          value: controller.killSwitch,
                          onChanged: (v) => _apply(
                            () => controller.setKillSwitch(v),
                            '断线保护设置已更新',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const V3SectionLabel('启动与更新'),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _SettingRow(
                        index: '04',
                        title: '开机启动',
                        description: '登录系统时自动启动 Litchi。',
                        control: _V3Switch(
                          value: controller.autoStart,
                          onChanged: controller.setAutoStart,
                        ),
                      ),
                      _SettingRow(
                        index: '05',
                        title: '静默启动',
                        description: '启动时隐藏主窗口。',
                        control: _V3Switch(
                          value: controller.silentStart,
                          onChanged: controller.setSilentStart,
                        ),
                      ),
                      _SettingRow(
                        index: '06',
                        title: '自动检查更新',
                        description: '在后台检查是否有新版本。',
                        last: true,
                        control: _V3Switch(
                          value: controller.autoUpdate,
                          onChanged: controller.setAutoUpdate,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const V3SectionLabel('外观'),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: _SettingRow(
                    index: '07',
                    title: '主题',
                    description: '选择浅色或深色界面。',
                    last: true,
                    control: _Segment<ThemeMode>(
                      value: controller.themeMode == ThemeMode.dark
                          ? ThemeMode.dark
                          : ThemeMode.light,
                      items: const [ThemeMode.light, ThemeMode.dark],
                      label: (v) => v == ThemeMode.dark ? '深色' : '浅色',
                      onChanged: controller.setThemeMode,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const V3SectionLabel('诊断与修复'),
                const SizedBox(height: 10),
                _RecoveryPanel(
                  controller: controller,
                  onRepair: () => _apply(() async {
                    await controller.fixProxy();
                    return null;
                  }, '已执行系统代理修复，请检查网络连接'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow<T> extends StatelessWidget {
  const _SettingRow({
    required this.index,
    required this.title,
    required this.description,
    required this.control,
    this.last = false,
  });

  final String index;
  final String title;
  final String description;
  final Widget control;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 600;
          final copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  index,
                  style: TextStyle(
                    color: p.lycheeInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          );
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    copy,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerRight, child: control),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 20),
                    control,
                  ],
                );
        },
      ),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.fillAvailableWidth = false,
  });

  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final bool fillAvailableWidth;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: items.map((item) {
        final selected = item == value;
        final segment = InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => onChanged(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            // 14 rather than 8 vertical: at the 12px label's line box that
            // puts the segment at ~45dp tall, clearing the 44dp a touch
            // target should offer. Measured, not guessed — 12 gave 41dp.
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              label(item),
              style: TextStyle(
                color: selected ? p.lycheeInk : p.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        return fillAvailableWidth ? Expanded(child: segment) : segment;
      }).toList(),
    );
    return Container(
      width: fillAvailableWidth ? double.infinity : null,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      // Intrinsically sized segments can outgrow narrow layouts (360dp and
      // below); scale them down instead of overflowing.
      child: fillAvailableWidth
          ? row
          : FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: row,
            ),
    );
  }
}

class _V3Switch extends StatelessWidget {
  const _V3Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Semantics(
      button: true,
      toggled: value,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 30,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? p.lychee : p.surfaceRaised,
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 160),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? Colors.white : p.inkMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({required this.controller, required this.onRepair});

  final AppController controller;
  final VoidCallback onRepair;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      tone: V3PanelTone.ink,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: p.citrus,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.build_circle_outlined, color: p.night, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '系统代理修复',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '端口 ${controller.activeProxyPort} · ${controller.networkMode.label}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onRepair,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('修复'),
          ),
        ],
      ),
    );
  }
}

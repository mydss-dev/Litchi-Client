import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';

class V3SettingsPage extends StatelessWidget {
  const V3SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(compact ? 20 : 34, 26, compact ? 20 : 34, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SYSTEM CONTROL', style: TextStyle(color: p.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
              const SizedBox(height: 7),
              Text('网络控制台', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 9),
              Text('不再用旧版“设置卡片堆叠”。V3 把关键网络行为放进连续控制轨道。', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 28),
              _SettingBand(
                index: '01',
                title: '接管方式',
                description: '决定 Litchi 如何接管系统流量。TUN 适合完整接管，系统代理更轻量。',
                trailing: _Segment<NetworkMode>(
                  value: controller.networkMode,
                  items: const [NetworkMode.system, NetworkMode.tun],
                  label: (value) => value == NetworkMode.system ? '系统代理' : 'TUN',
                  onChanged: controller.setNetworkMode,
                ),
              ),
              _SettingBand(
                index: '02',
                title: 'DNS 路径',
                description: '选择隧道使用的解析路径；系统 DNS 更贴近本机，Cloudflare / Google 更独立。',
                trailing: _Segment<DnsMode>(
                  value: controller.dnsMode,
                  items: const [DnsMode.system, DnsMode.cloudflare, DnsMode.google],
                  label: (value) => switch (value) {
                    DnsMode.system => '系统',
                    DnsMode.cloudflare => 'CF',
                    DnsMode.google => 'Google',
                  },
                  onChanged: controller.setDnsMode,
                ),
              ),
              _SettingBand(
                index: '03',
                title: 'Kill Switch',
                description: 'TUN 意外中断时阻止流量绕过隧道。只在需要严格防泄漏时开启。',
                trailing: _V3Switch(value: controller.killSwitch, onChanged: controller.setKillSwitch),
              ),
              _SettingBand(
                index: '04',
                title: '随系统启动',
                description: 'Windows / macOS 登录后自动启动 Litchi。',
                trailing: _V3Switch(value: controller.autoStart, onChanged: controller.setAutoStart),
              ),
              _SettingBand(
                index: '05',
                title: '静默启动',
                description: '自动启动时隐藏主窗口，只保留后台连接能力。',
                trailing: _V3Switch(value: controller.silentStart, onChanged: controller.setSilentStart),
              ),
              _SettingBand(
                index: '06',
                title: '自动更新',
                description: '允许 Litchi 检查签名更新清单并提示新版本。',
                trailing: _V3Switch(value: controller.autoUpdate, onChanged: controller.setAutoUpdate),
              ),
              _SettingBand(
                index: '07',
                title: '界面主题',
                description: 'V3 仅保留 Light / Dark，两套界面分别设计，不增加多余颜色模式。',
                trailing: _Segment<ThemeMode>(
                  value: controller.themeMode == ThemeMode.dark ? ThemeMode.dark : ThemeMode.light,
                  items: const [ThemeMode.light, ThemeMode.dark],
                  label: (value) => value == ThemeMode.dark ? 'Dark' : 'Light',
                  onChanged: controller.setThemeMode,
                ),
              ),
              const SizedBox(height: 24),
              _DiagnosticsStrip(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _SettingBand extends StatelessWidget {
  const _SettingBand({
    required this.index,
    required this.title,
    required this.description,
    required this.trailing,
  });

  final String index;
  final String title;
  final String description;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final text = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 42,
                child: Text(index, style: TextStyle(color: p.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.6)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(description, style: TextStyle(color: p.textMuted, fontSize: 11, height: 1.45)),
                  ],
                ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                text,
                const SizedBox(height: 14),
                Align(alignment: Alignment.centerRight, child: trailing),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 26),
              trailing,
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
  });

  final T value;
  final List<T> items;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.panelStrong, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final selected = item == value;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onChanged(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? p.panel : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: selected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Text(label(item), style: TextStyle(color: selected ? p.text : p.textMuted, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          );
        }).toList(),
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: value ? p.accent : p.panelStrong, borderRadius: BorderRadius.circular(20)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}

class _DiagnosticsStrip extends StatelessWidget {
  const _DiagnosticsStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.rail, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.build_circle_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NETWORK RECOVERY', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('当前代理端口 ${controller.activeProxyPort} · ${controller.networkMode.label}', style: TextStyle(color: Colors.white.withValues(alpha: 0.48), fontSize: 10)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: controller.fixProxy,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('修复代理'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';

class V3SettingsPage extends StatelessWidget {
  const V3SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 30,
            28,
            compact ? 20 : 30,
            34,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const V3PageHeader(
                kicker: 'System control',
                title: 'Make the network yours',
                description:
                    'Every setting is a deliberate trade-off between reach, privacy, and convenience.',
              ),
              const SizedBox(height: 24),
              V3Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SettingRow(
                      index: '01',
                      title: 'Traffic capture',
                      description:
                          'Choose how Litchi takes ownership of device traffic.',
                      control: _Segment<NetworkMode>(
                        value: controller.networkMode,
                        items: const [NetworkMode.system, NetworkMode.tun],
                        label: (v) =>
                            v == NetworkMode.system ? 'System proxy' : 'TUN',
                        onChanged: controller.setNetworkMode,
                        fillAvailableWidth: compact,
                      ),
                    ),
                    _SettingRow(
                      index: '02',
                      title: 'DNS route',
                      description:
                          'Keep resolution local or send it through an independent resolver.',
                      control: _Segment<DnsMode>(
                        value: controller.dnsMode,
                        items: const [
                          DnsMode.system,
                          DnsMode.cloudflare,
                          DnsMode.google,
                        ],
                        label: (v) => switch (v) {
                          DnsMode.system => 'System',
                          DnsMode.cloudflare => 'Cloudflare',
                          DnsMode.google => 'Google',
                        },
                        onChanged: controller.setDnsMode,
                        fillAvailableWidth: compact,
                      ),
                    ),
                    _SettingRow(
                      index: '03',
                      title: 'Kill switch',
                      description:
                          'Block traffic if the tunnel drops unexpectedly.',
                      control: _V3Switch(
                        value: controller.killSwitch,
                        onChanged: controller.setKillSwitch,
                      ),
                    ),
                    _SettingRow(
                      index: '04',
                      title: 'Launch with system',
                      description: 'Start Litchi when you sign in.',
                      control: _V3Switch(
                        value: controller.autoStart,
                        onChanged: controller.setAutoStart,
                      ),
                    ),
                    _SettingRow(
                      index: '05',
                      title: 'Quiet launch',
                      description:
                          'Keep the workspace hidden while the service starts.',
                      control: _V3Switch(
                        value: controller.silentStart,
                        onChanged: controller.setSilentStart,
                      ),
                    ),
                    _SettingRow(
                      index: '06',
                      title: 'Automatic updates',
                      description:
                          'Check signed release metadata in the background.',
                      control: _V3Switch(
                        value: controller.autoUpdate,
                        onChanged: controller.setAutoUpdate,
                      ),
                    ),
                    _SettingRow(
                      index: '07',
                      title: 'Appearance',
                      description:
                          'Light and dark are separate compositions of the Litchi palette.',
                      control: _Segment<ThemeMode>(
                        value: controller.themeMode == ThemeMode.dark
                            ? ThemeMode.dark
                            : ThemeMode.light,
                        items: const [ThemeMode.light, ThemeMode.dark],
                        label: (v) => v == ThemeMode.dark ? 'Dark' : 'Light',
                        onChanged: controller.setThemeMode,
                        fillAvailableWidth: compact,
                      ),
                      last: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _RecoveryPanel(controller: controller),
            ],
          ),
        );
      },
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
          final stacked = constraints.maxWidth < 560;
          final copy = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  index,
                  style: TextStyle(
                    color: p.lychee,
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
    return Container(
      width: fillAvailableWidth ? double.infinity : null,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final selected = item == value;
          final segment = InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => onChanged(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? p.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                label(item),
                style: TextStyle(
                  color: selected ? p.lychee : p.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
          return fillAvailableWidth ? Expanded(child: segment) : segment;
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
  const _RecoveryPanel({required this.controller});

  final AppController controller;

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
                  'RECOVERY CONSOLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Port ${controller.activeProxyPort} · ${controller.networkMode.label}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: controller.fixProxy,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Repair'),
          ),
        ],
      ),
    );
  }
}

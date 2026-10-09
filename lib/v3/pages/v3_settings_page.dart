import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_language_selector.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_toast.dart';

// Reuse the existing ARB translations for established UI copy. These short
// hints have no ARB entries yet; keeping them together avoids mixing Chinese
// into English settings while the wider V3 localization migration proceeds.
String _hint(AppLocalizations l, {required String zh, required String en,
    required String tw}) {
  if (l.localeName.startsWith('en')) return en;
  if (l.localeName.toLowerCase().contains('tw')) return tw;
  return zh;
}

AppLocalizations _copy(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    AppLocalizationsZh();

/// Startup and system-proxy tools are meaningful on Windows/macOS only.
bool v3HasDesktopSystemTools(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS;

class V3SettingsPage extends StatefulWidget {
  const V3SettingsPage({super.key});

  @override
  State<V3SettingsPage> createState() => _V3SettingsPageState();
}

class _V3SettingsPageState extends State<V3SettingsPage> {
  // The setting currently applying: its control dims under a spinner (the
  // nodes page's per-row busy pattern) and the result surfaces as a V3Toast,
  // instead of a banner line that shifted every section down and never left.
  String? _pending;
  late final Future<String> _coreVersionFuture = _loadCoreVersion();

  Future<String> _loadCoreVersion() async {
    try {
      return await AppController.getCoreVersion();
    } catch (_) {
      return '';
    }
  }

  Future<void> _apply(
    String id,
    Future<String?> Function() action,
    String success,
  ) async {
    if (_pending != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    final l = _copy(context);
    final failureSuffix = _hint(l,
      zh: '。请重试或重新连接。',
      en: '. Retry or reconnect.',
      tw: '。請重試或重新連線。');
    final failureText = _hint(l,
      zh: '设置未能完成，请重试或修复网络。',
      en: 'Settings could not be applied. Retry or reconnect.',
      tw: '設定未能完成，請重試或重新連線。');
    setState(() => _pending = id);
    String? error;
    try {
      error = await action();
    } catch (_) {
      error = failureText;
    }
    if (!mounted) return;
    // Same voice as every other V3 surface: transient overlay feedback (M3
    // snackbar guidance), resolved on the root overlay so it outlives scroll.
    V3Toast.showInOverlay(overlay,
      error == null ? success : '$error$failureSuffix',
      type: error == null ? V3ToastType.success : V3ToastType.error);
    setState(() => _pending = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final l = _copy(context);
    final desktopTools = v3HasDesktopSystemTools(defaultTargetPlatform);
    final currentNetwork = controller.networkMode == NetworkMode.system
        ? l.systemProxy : l.tunMode;
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: v3Copy(context, zh: '应用设置',
              en: 'APP SETTINGS', tw: '應用設定'),
            title: v3Copy(context,
              zh: '设置中心', en: 'Settings', tw: '設定中心'),
            description: l.settingsSubtitle,
          ),
          const SizedBox(height: 18),
          AbsorbPointer(
            absorbing: _pending != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V3SectionLabel(l.systemSettings),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    if (desktopTools) _SettingRow(
                      icon: Icons.power_settings_new_rounded,
                      title: l.launchAtStartup,
                      description: _hint(l,
                        zh: '登录系统时自动启动 Litchi。',
                        en: 'Start Litchi automatically when you sign in.',
                        tw: '登入系統時自動啟動 Litchi。'),
                      busy: _pending == 'autoStart',
                      control: V3Switch(value: controller.autoStart,
                        onChanged: (v) => _apply('autoStart', () async {
                          controller.setAutoStart(v);
                          return null;
                        }, l.settingsUpdated)),
                    ),
                    if (desktopTools) _SettingRow(
                      icon: Icons.visibility_off_rounded,
                      title: l.silentStartup,
                      description: _hint(l,
                        zh: '启动时隐藏主窗口。',
                        en: 'Hide the main window at startup.',
                        tw: '啟動時隱藏主視窗。'),
                      busy: _pending == 'silentStart',
                      control: V3Switch(value: controller.silentStart,
                        onChanged: (v) => _apply('silentStart', () async {
                          controller.setSilentStart(v);
                          return null;
                        }, l.settingsUpdated)),
                    ),
                    _SettingRow(
                      icon: Icons.system_update_alt_rounded,
                      title: l.automaticUpdates,
                      description: _hint(l,
                        zh: '在后台检查是否有新版本。',
                        en: 'Check for new versions in the background.',
                        tw: '在背景檢查是否有新版本。'),
                      last: true,
                      busy: _pending == 'autoUpdate',
                      control: V3Switch(value: controller.autoUpdate,
                        onChanged: (v) => _apply('autoUpdate', () async {
                          controller.setAutoUpdate(v);
                          return null;
                        }, l.settingsUpdated)),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                V3SectionLabel(l.appearance),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    _SettingRow(
                      icon: Icons.dark_mode_rounded,
                      title: l.appearance,
                      description: _hint(l,
                        zh: '跟随系统外观，或手动选择浅色和深色界面。',
                        en: 'Follow your system appearance or choose light/dark.',
                        tw: '跟隨系統外觀，或手動選擇淺色與深色介面。'),
                      fullWidthControl: true,
                      control: _Segment<ThemeMode>(
                        value: controller.themeMode,
                        items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                        label: (v) => switch (v) {
                          ThemeMode.system => l.followSystem,
                          ThemeMode.light => l.lightMode,
                          ThemeMode.dark => l.darkMode,
                        },
                        onChanged: controller.setThemeMode,
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.language_rounded,
                      title: l.language,
                      description: _hint(l,
                        zh: '选择界面语言；跟随系统将使用设备的语言。',
                        en: 'Choose an interface language or follow your device.',
                        tw: '選擇介面語言；跟隨系統將使用裝置語言。'),
                      fullWidthControl: true,
                      last: true,
                      control: const V3LanguageSelector(),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                V3SectionLabel(l.connectionSettings),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    if (desktopTools) _SettingRow(
                      icon: Icons.swap_horiz_rounded,
                      title: l.connectionMethod,
                      description: '${l.systemProxyDescription}; ${l.tunDescription}.',
                      fullWidthControl: true,
                      busy: _pending == 'networkMode',
                      control: _Segment<NetworkMode>(
                        value: controller.networkMode,
                        items: const [NetworkMode.system, NetworkMode.tun],
                        label: (v) => v == NetworkMode.system ? l.systemProxy : l.tunMode,
                        onChanged: (v) => _apply(
                          'networkMode',
                          () => controller.setNetworkMode(v),
                          controller.coreProcessRunning
                              ? l.networkModeReconnect : l.proxyModeNextConnection,
                        ),
                      ),
                    ),
                    _SettingRow(
                      icon: Icons.dns_rounded,
                      title: l.dns,
                      description: _hint(l,
                        zh: '使用系统 DNS，或选择其他解析服务。',
                        en: 'Use system DNS or choose another resolver.',
                        tw: '使用系統 DNS，或選擇其他解析服務。'),
                      last: !desktopTools,
                      fullWidthControl: true,
                      busy: _pending == 'dns',
                      control: _Segment<DnsMode>(
                        value: controller.dnsMode,
                        items: const [DnsMode.system, DnsMode.cloudflare, DnsMode.google],
                        label: (v) => switch (v) {
                          DnsMode.system => l.systemDns,
                          DnsMode.cloudflare => 'Cloudflare',
                          DnsMode.google => 'Google',
                        },
                        onChanged: (v) => _apply(
                          'dns',
                          () => controller.setDnsMode(v),
                          l.settingsUpdated,
                        ),
                      ),
                    ),
                    if (desktopTools) _SettingRow(
                      icon: Icons.shield_outlined,
                      title: l.connectionProtection,
                      description: _hint(l,
                        zh: '节点意外断开时暂停联网，防止流量绕过代理直接暴露；重新连接后自动恢复。',
                        en: 'Pauses internet if the node drops unexpectedly '
                            'so traffic cannot bypass the proxy; resumes '
                            'automatically on reconnect.',
                        tw: '節點意外斷開時暫停連網，防止流量繞過代理直接暴露；重新連線後自動恢復。'),
                      last: true,
                      busy: _pending == 'killSwitch',
                      control: V3Switch(
                        value: controller.killSwitch,
                        onChanged: (v) => _apply(
                          'killSwitch',
                          () => controller.setKillSwitch(v), l.settingsUpdated),
                      ),
                    ),
                  ]),
                ),
                if (desktopTools) ...[
                  const SizedBox(height: 22),
                  V3SectionLabel(l.repairNetworkSettings),
                  const SizedBox(height: 10),
                  _RecoveryPanel(
                    controller: controller,
                    label: currentNetwork,
                    title: l.repairSystemProxy,
                    action: l.repair,
                    busy: _pending == 'repair',
                    onRepair: () => _apply('repair', () async {
                      await controller.fixProxy();
                      return null;
                    }, l.networkSettingsRepaired),
                  ),
                ],
                const SizedBox(height: 22),
                V3SectionLabel(l.about),
                const SizedBox(height: 10),
                V3Panel(
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.appVersion,
                          style: TextStyle(color: p.inkMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        Text(AppConfig.currentVersion.trim().isEmpty
                            ? '—' : AppConfig.currentVersion,
                          style: TextStyle(color: p.ink,
                            fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    )),
                    Container(width: 1, height: 38, color: p.line),
                    const SizedBox(width: 18),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.coreVersion,
                          style: TextStyle(color: p.inkMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        FutureBuilder<String>(
                          future: _coreVersionFuture,
                          builder: (context, snapshot) {
                            final version = snapshot.data?.trim() ?? '';
                            return Text(snapshot.connectionState !=
                                    ConnectionState.done ? l.loading
                                  : version.isEmpty ? '—' : version,
                              style: TextStyle(color: p.ink,
                                fontSize: 14, fontWeight: FontWeight.w800));
                          },
                        ),
                      ],
                    )),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title,
    required this.description, required this.control, this.last = false,
    this.fullWidthControl = false, this.busy = false});

  final IconData icon;
  final String title;
  final String description;
  final Widget control;
  final bool last;
  final bool fullWidthControl;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: p.line)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 600;
        // The same identity tile the node rows use (raised fill, one ink
        // glyph): setting rows read as the same family as list rows
        // elsewhere in V3 instead of an editorial numbered index.
        final tile = Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surfaceRaised,
            borderRadius: BorderRadius.circular(V3Radius.control),
          ),
          child: Icon(icon, color: p.ink, size: 19),
        );
        final copy = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile,
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            )),
          ],
        );
        // While the setting applies, the control stays in place (no layout
        // shift) but dims under a small spinner: the affected control carries
        // the progress (M3), not the whole page.
        Widget slot(Widget control) => !busy
            ? control
            : Stack(alignment: Alignment.center, children: [
                Opacity(opacity: 0.35,
                  child: AbsorbPointer(absorbing: true, child: control)),
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              ]);
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                copy, const SizedBox(height: 14),
                if (fullWidthControl) slot(control)
                else Align(alignment: Alignment.centerRight, child: slot(control)),
              ])
            : Row(children: [
                Expanded(child: copy), const SizedBox(width: 20),
                if (fullWidthControl) SizedBox(width: 240, child: slot(control))
                else slot(control),
              ]);
      }),
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.value, required this.items,
    required this.label, required this.onChanged});

  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised, borderRadius: BorderRadius.circular(V3Radius.field)),
      child: Row(children: items.map((item) {
        final selected = item == value;
        // V3Pressable paints the ink above the raised track fill instead of
        // on the root Material beneath it.
        return Expanded(child: V3Pressable(
          key: ValueKey('v3-settings-segment-${label(item)}'),
          borderRadius: BorderRadius.circular(V3Radius.control),
          onTap: () => onChanged(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(V3Radius.control),
            ),
            child: Text(label(item), textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: selected ? p.lycheeInk : p.inkMuted,
                fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ));
      }).toList()),
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({required this.controller, required this.label,
    required this.title, required this.action, required this.onRepair,
    this.busy = false});
  final AppController controller;
  final String label;
  final String title;
  final String action;
  final VoidCallback onRepair;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final l = _copy(context);
    return V3Panel(
      tone: V3PanelTone.hero,
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: p.citrus,
            borderRadius: BorderRadius.circular(V3Radius.field)),
          child: Icon(Icons.build_circle_outlined, color: p.night, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: p.ink,
              fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${l.diagnosticProxyPort(controller.activeProxyPort)} · $label',
              style: TextStyle(color: p.inkMuted, fontSize: 12)),
          ])),
        OutlinedButton(
          onPressed: busy ? null : onRepair,
          style: OutlinedButton.styleFrom(foregroundColor: p.ink,
            side: BorderSide(color: p.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.field))),
          child: busy
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(action),
        ),
      ]),
    );
  }
}

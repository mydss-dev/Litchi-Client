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
  bool _busy = false;
  bool _failed = false;
  String? _message;
  late final Future<String> _coreVersionFuture = _loadCoreVersion();

  Future<String> _loadCoreVersion() async {
    try {
      return await AppController.getCoreVersion();
    } catch (_) {
      return '';
    }
  }

  Future<void> _apply(Future<String?> Function() action, String success) async {
    if (_busy) return;
    final l = _copy(context);
    setState(() {
      _busy = true;
      _message = _hint(l,
        zh: '正在应用设置，请稍候…', en: 'Applying settings, please wait…',
        tw: '正在套用設定，請稍候…');
      _failed = false;
    });
    try {
      final error = await action();
      if (mounted) {
        setState(() {
          _failed = error != null;
          _message = error == null ? success :
              '$error${_hint(_copy(context), zh: '。请重试或重新连接。',
                en: '. Retry or reconnect.', tw: '。請重試或重新連線。')}';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = _hint(_copy(context),
            zh: '设置未能完成，请重试或重新连接。',
            en: 'Settings could not be applied. Retry or reconnect.',
            tw: '設定未能完成，請重試或重新連線。');
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
    final l = _copy(context);
    final desktopTools = v3HasDesktopSystemTools(defaultTargetPlatform);
    final currentNetwork = controller.networkMode == NetworkMode.system
        ? l.systemProxy : l.tunMode;
    return SingleChildScrollView(
      padding: V3Layout.pageInsets,
      child: Column(
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
          if (_message != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_message!, style: TextStyle(
                color: _failed ? p.dangerInk : p.inkMuted, fontSize: 13)),
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
                V3SectionLabel(l.systemSettings),
                const SizedBox(height: 10),
                V3Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    if (desktopTools) _SettingRow(
                      index: '01', title: l.launchAtStartup,
                      description: _hint(l,
                        zh: '登录系统时自动启动 Litchi。',
                        en: 'Start Litchi automatically when you sign in.',
                        tw: '登入系統時自動啟動 Litchi。'),
                      control: V3Switch(value: controller.autoStart,
                        onChanged: (v) => _apply(() async {
                          controller.setAutoStart(v);
                          return null;
                        }, l.settingsUpdated)),
                    ),
                    if (desktopTools) _SettingRow(
                      index: '02', title: l.silentStartup,
                      description: _hint(l,
                        zh: '启动时隐藏主窗口。',
                        en: 'Hide the main window at startup.',
                        tw: '啟動時隱藏主視窗。'),
                      control: V3Switch(value: controller.silentStart,
                        onChanged: (v) => _apply(() async {
                          controller.setSilentStart(v);
                          return null;
                        }, l.settingsUpdated)),
                    ),
                    _SettingRow(
                      index: desktopTools ? '03' : '01', title: l.automaticUpdates,
                      description: _hint(l,
                        zh: '在后台检查是否有新版本。',
                        en: 'Check for new versions in the background.',
                        tw: '在背景檢查是否有新版本。'),
                      last: true,
                      control: V3Switch(value: controller.autoUpdate,
                        onChanged: (v) => _apply(() async {
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
                      index: desktopTools ? '04' : '02', title: l.appearance,
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
                      index: desktopTools ? '05' : '03', title: l.language,
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
                      index: '06',
                      title: l.connectionMethod,
                      description: '${l.systemProxyDescription}; ${l.tunDescription}.',
                      fullWidthControl: true,
                      control: _Segment<NetworkMode>(
                        value: controller.networkMode,
                        items: const [NetworkMode.system, NetworkMode.tun],
                        label: (v) => v == NetworkMode.system ? l.systemProxy : l.tunMode,
                        onChanged: (v) => _apply(
                          () => controller.setNetworkMode(v),
                          controller.coreProcessRunning
                              ? l.networkModeReconnect : l.proxyModeNextConnection,
                        ),
                      ),
                    ),
                    _SettingRow(
                      index: desktopTools ? '07' : '04', title: l.dns,
                      description: _hint(l,
                        zh: '使用系统 DNS，或选择其他解析服务。',
                        en: 'Use system DNS or choose another resolver.',
                        tw: '使用系統 DNS，或選擇其他解析服務。'),
                      last: !desktopTools,
                      fullWidthControl: true,
                      control: _Segment<DnsMode>(
                        value: controller.dnsMode,
                        items: const [DnsMode.system, DnsMode.cloudflare, DnsMode.google],
                        label: (v) => switch (v) {
                          DnsMode.system => l.systemDns,
                          DnsMode.cloudflare => 'Cloudflare',
                          DnsMode.google => 'Google',
                        },
                        onChanged: (v) => _apply(
                          () => controller.setDnsMode(v),
                          l.settingsUpdated,
                        ),
                      ),
                    ),
                    if (desktopTools) _SettingRow(
                      index: '08', title: l.connectionProtection,
                      description: _hint(l,
                        zh: '节点意外断开时暂停联网，防止流量绕过代理直接暴露；重新连接后自动恢复。',
                        en: 'Pauses internet if the node drops unexpectedly '
                            'so traffic cannot bypass the proxy; resumes '
                            'automatically on reconnect.',
                        tw: '節點意外斷開時暫停連網，防止流量繞過代理直接暴露；重新連線後自動恢復。'),
                      last: true,
                      control: V3Switch(
                        value: controller.killSwitch,
                        onChanged: (v) => _apply(
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
                    onRepair: () => _apply(() async {
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
  const _SettingRow({required this.index, required this.title,
    required this.description, required this.control, this.last = false,
    this.fullWidthControl = false});

  final String index;
  final String title;
  final String description;
  final Widget control;
  final bool last;
  final bool fullWidthControl;

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
        final copy = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 38, child: Text(index, style: TextStyle(
              color: p.lycheeInk, fontSize: 10, fontWeight: FontWeight.w900,
              letterSpacing: 1.4))),
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
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                copy, const SizedBox(height: 14),
                if (fullWidthControl) control
                else Align(alignment: Alignment.centerRight, child: control),
              ])
            : Row(children: [
                Expanded(child: copy), const SizedBox(width: 20),
                if (fullWidthControl) SizedBox(width: 240, child: control)
                else control,
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
        return Expanded(child: InkWell(
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
    required this.title, required this.action, required this.onRepair});
  final AppController controller;
  final String label;
  final String title;
  final String action;
  final VoidCallback onRepair;

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
          onPressed: onRepair,
          style: OutlinedButton.styleFrom(foregroundColor: p.ink,
            side: BorderSide(color: p.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(V3Radius.field))),
          child: Text(action),
        ),
      ]),
    );
  }
}

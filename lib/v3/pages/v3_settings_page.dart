import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';
import '../../l10n/app_locale_preference.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_dropdown.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_mobile_components.dart';
import '../ui/v3_toast.dart';
import '../../shared/theme/app_icons.dart';

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
    final phone = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
    Widget group({required Widget child, EdgeInsetsGeometry padding = EdgeInsets.zero}) =>
        phone ? V3MobileCard(padding: padding, child: child)
            : V3Panel(padding: padding, child: child);
    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: phone ? V3MobileDesign.pageInsets : V3Layout.pageInsets,
      child: V3WaveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
              backPage: AppPage.account,
            title: v3Copy(context,
              zh: '设置中心', en: 'Settings', tw: '設定中心'),
            subtitle: v3Copy(context,
              zh: '外观 · 代理 · 网络 · 关于',
              en: 'Appearance · Proxy · Network · About',
              tw: '外觀 · 代理 · 網路 · 關於'),
          ),
          const SizedBox(height: 18),
          AbsorbPointer(
            absorbing: _pending != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                V3SectionLabel(l.systemSettings),
                const SizedBox(height: 10),
                group(
                  child: Column(children: [
                    if (desktopTools) _SettingRow(
                      icon: AppIcons.power,
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
                      icon: AppIcons.hidden,
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
                      icon: AppIcons.download,
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
                group(
                  child: Column(children: [
                    _SettingField(
                      icon: AppIcons.sleep,
                      title: _hint(l, zh: '主题', en: 'Theme', tw: '主題'),
                      description: _hint(l,
                        zh: '跟随系统外观，或手动选择浅色和深色界面。',
                        en: 'Follow your system appearance or choose light/dark.',
                        tw: '跟隨系統外觀，或手動選擇淺色與深色介面。'),
                      control: V3MobileSegmented(
                        key: const ValueKey('v3-theme-select'),
                        labels: [
                          l.followSystem, l.lightMode, l.darkMode,
                        ],
                        icons: const [
                          AppIcons.devices, AppIcons.daylight, AppIcons.sleep,
                        ],
                        selectedIndex: switch (controller.themeMode) {
                          ThemeMode.system => 0,
                          ThemeMode.light => 1,
                          ThemeMode.dark => 2,
                        },
                        onChanged: (i) => controller.setThemeMode(
                          switch (i) {
                            0 => ThemeMode.system,
                            1 => ThemeMode.light,
                            _ => ThemeMode.dark,
                          },
                        ),
                      ),
                    ),
                    _SettingField(
                      icon: AppIcons.language,
                      title: l.language,
                      description: _hint(l,
                        zh: '选择界面语言；跟随系统将使用设备的语言。',
                        en: 'Choose an interface language or follow your device.',
                        tw: '選擇介面語言；跟隨系統將使用裝置語言。'),
                      last: true,
                      control: V3Dropdown<AppLocalePreference>(
                        key: const ValueKey('v3-language-select'),
                        value: controller.language,
                        items: AppLocalePreference.values,
                        label: (v) => switch (v) {
                          AppLocalePreference.system => l.followSystem,
                          AppLocalePreference.simplifiedChinese => l.simplifiedChinese,
                          AppLocalePreference.traditionalChinese => l.traditionalChinese,
                          AppLocalePreference.english => l.english,
                        },
                        onChanged: controller.setLanguage,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 22),
                V3SectionLabel(l.connectionSettings),
                const SizedBox(height: 10),
                group(
                  child: Column(children: [
                    // Read-only mirror row: the Connect page's segments own
                    // proxy mode, so this row only names the current mode and
                    // where switching happens — no second control to drift.
                    _SettingRow(
                      icon: AppIcons.shield,
                      title: v3Copy(context,
                        zh: '代理模式', en: 'Network mode', tw: '代理模式'),
                      description: _hint(l,
                        zh: '在连接页切换',
                        en: 'Switch on the Connect page',
                        tw: '在連線頁切換'),
                      control: Text(
                        currentNetwork,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _SettingRow(
                      icon: AppIcons.server,
                      title: l.dns,
                      description: _hint(l,
                        zh: '使用系统 DNS，或选择其他解析服务。',
                        en: 'Use system DNS or choose another resolver.',
                        tw: '使用系統 DNS，或選擇其他解析服務。'),
                      last: !desktopTools,
                      busy: _pending == 'dns',
                      control: V3Dropdown<DnsMode>(
                        key: const ValueKey('v3-dns-select'),
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
                        width: 168,
                      ),
                    ),
                    if (desktopTools) _SettingRow(
                      // Round-3 audit F37: one icon family per surface —
                      // every content glyph here is rounded; the outlined
                      // variant mixed families inside the same panel.
                      icon: AppIcons.shield,
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
                group(
                  padding: const EdgeInsets.all(20),
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
    return phone ? V3MobileBackdrop(child: scroll) : scroll;
  }
}

/// A setting whose control is too wide for a trailing slot (segmented
/// switches, full-width dropdowns). The copy rides above the control, which
/// spans the card — the reference's 外观 layout, distinct from the compact
/// [_SettingRow] used for switches and narrow values.
class _SettingField extends StatelessWidget {
  const _SettingField({required this.icon, required this.title,
    required this.description, required this.control, this.last = false});

  final IconData icon;
  final String title;
  final String description;
  final Widget control;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 17),
      decoration: last ? null : BoxDecoration(
        border: Border(bottom: BorderSide(color: p.line)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceRaised,
              borderRadius: BorderRadius.circular(V3Radius.control),
            ),
            child: Icon(icon, color: p.ink, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
        ]),
        const SizedBox(height: 14),
        control,
      ]),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.icon, required this.title,
    required this.description, required this.control, this.last = false,
    this.busy = false});

  final IconData icon;
  final String title;
  final String description;
  final Widget control;
  final bool last;
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
        // The desktop pane (688dp at the 900px window, less insets, the panel
        // border and a scrollbar) lands just above 600, so a hard 600 here
        // flips desktop rows into their stacked phone layout. Reuse the
        // page-level compact breakpoint instead: rows stay single-line on the
        // desktop and only wrap where the whole page already goes compact.
        final stacked = constraints.maxWidth < V3Layout.paneCompact;
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
        Widget slot(Widget c) => !busy
            ? c
            : Stack(alignment: Alignment.center, children: [
                Opacity(opacity: 0.35,
                  child: AbsorbPointer(absorbing: true, child: c)),
                const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              ]);
        // A control never leaves its title line on a wide pane: it sits right
        // of the copy, so every row reads "title left / control right". On a
        // narrow pane the control drops below the copy, left-aligned.
        // Switches always ride the title line (iOS/Android list convention);
        // only wide controls such as dropdowns drop below on narrow panes,
        // and then they span the row instead of floating at half width.
        if (control is V3Switch || constraints.maxWidth >= 168 + 12 + 150) {
          return Row(children: [
            Expanded(child: copy),
            const SizedBox(width: 12),
            slot(control),
          ]);
        }
        return stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                copy,
                const SizedBox(height: 12),
                Padding(padding: const EdgeInsets.only(left: 50),
                  child: slot(control)),
              ])
            : Row(children: [
                Expanded(child: copy),
                const SizedBox(width: 20),
                slot(control),
              ]);
      }),
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
          child: Icon(AppIcons.wrench, color: p.night, size: 21),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../app/plan_presentation.dart';
import '../../shared/models/app_models.dart';
import '../../shared/services/connectivity_check_service.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_dashboard_alerts.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_toast.dart';
import '../ui/v3_node_tags.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_notice_bar.dart';

/// One connection page: the desktop rail must never add a second Home route.
class V3DashboardPage extends StatelessWidget {
  const V3DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final status = controller.connectionStatus;
    // Only a confirmed account without a plan sees the purchase guidance.
    final confirmedNoPlan = !controller.isInitialLoading &&
        controller.hasConfirmedNoPlan;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: V3Layout.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          V3NoticeBar(controller: controller),
          V3DashboardAlerts(controller: controller),
          if (confirmedNoPlan)
            _NoPlanDashboardPanel(controller: controller)
          else ...[
            _ConnectionWorkspace(
              controller: controller,
              connected: status == ConnectionStatus.connected,
              connecting:
                  status == ConnectionStatus.connecting ||
                  status == ConnectionStatus.disconnecting,
            ),
            const SizedBox(height: 12),
            _ModeRail(controller: controller),
            const SizedBox(height: 12),
            _SessionMetrics(controller: controller),
            const SizedBox(height: 12),
            _PlanSummary(controller: controller),
          ],
        ],
      ),
    );
  }
}

/// Purpose-built empty state without changing the connected dashboard layout.
class _NoPlanDashboardPanel extends StatelessWidget {
  const _NoPlanDashboardPanel({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final canBuy = isPageEnabled(AppPage.shop);
    return _DashboardCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 34, color: p.lychee),
            const SizedBox(height: 12),
            Text(v3Copy(context, zh: '当前没有可用套餐',
              en: 'No active plan', tw: '目前沒有可用方案'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(v3Copy(context,
              zh: canBuy ? '选择套餐后即可开始连接。' : '请联系服务商开通套餐。',
              en: canBuy ? 'Choose a plan to start connecting.'
                  : 'Contact your provider to activate a plan.',
              tw: canBuy ? '選擇方案後即可開始連線。' : '請聯絡服務商開通方案。'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 12)),
            if (canBuy) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('v3-dashboard-no-plan-buy'),
                onPressed: () => controller.goToPage(AppPage.shop),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee, foregroundColor: p.onLychee,
                  minimumSize: const Size(156, 44)),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: Text(v3Copy(context, zh: '选择套餐',
                  en: 'Choose a plan', tw: '選擇方案')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A near-black local surface in dark mode; light mode keeps its own palette.
/// Do not replace the app canvas with the gray-green mockup background.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) =>
      V3WorkspaceCard(padding: padding, child: child);
}

const kConnectActionCardKey = Key('v3-connect-action-card');
const kCurrentNodeCardKey = Key('v3-current-node-card');
const kConnectOrbKey = Key('v3-connect-orb');

class _ConnectionWorkspace extends StatelessWidget {
  const _ConnectionWorkspace({
    required this.controller,
    required this.connected,
    required this.connecting,
  });
  final AppController controller;
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final statusColor = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.inkMuted,
    };
    final node = controller.currentNode;
    // In automatic mode the card still names the node the resolver picked —
    // only the flag changing told users which node they were on before.
    final displayName = controller.autoSelected
        ? node.name.isEmpty
              ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
              : node.name
        : node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点', en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 500;
        final cardHeight = stacked ? 224.0 : 236.0;
        final intro = SizedBox(
          key: kConnectActionCardKey,
          height: cardHeight,
          child: _DashboardCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(V3Radius.card),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: Theme.of(context).brightness == Brightness.dark
                            ? .065
                            : .035,
                        child: SvgPicture.asset(
                          'assets/images/world_coastline.svg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v3Copy(
                              context,
                              zh: '连接状态',
                              en: 'Connection',
                              tw: '連線狀態',
                            ),
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _statusLabel(context, status),
                            style: TextStyle(color: statusColor, fontSize: 11),
                          ),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ConnectionOrb(
                                    controller: controller,
                                    connected: connected,
                                    connecting: connecting,
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    connected
                                        ? v3Copy(
                                            context,
                                            zh: '断开连接',
                                            en: 'Disconnect',
                                            tw: '中斷連線',
                                          )
                                        : connecting
                                        ? v3Copy(
                                            context,
                                            zh: '处理中',
                                            en: 'Processing',
                                            tw: '處理中',
                                          )
                                        : v3Copy(
                                            context,
                                            zh: '点击开始连接',
                                            en: 'Tap to connect',
                                            tw: '點擊開始連線',
                                          ),
                                    style: TextStyle(
                                      color: p.ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  _ConnectionDuration(controller: controller),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        final route = SizedBox(
          key: kCurrentNodeCardKey,
          height: cardHeight,
          child: _DashboardCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v3Copy(
                          context,
                          zh: '当前节点',
                          en: 'Current node',
                          tw: '目前節點',
                        ),
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    V3StatusBadge(
                      label: _statusLabel(context, status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.surfaceRaised,
                        borderRadius: BorderRadius.circular(V3Radius.field),
                      ),
                      child: V3NodeFlag(code: node.code),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (controller.autoSelected &&
                                  node.name.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.lycheeSoft,
                                    borderRadius:
                                        BorderRadius.circular(99), // pill
                                  ),
                                  child: Text(
                                    v3Copy(
                                      context,
                                      zh: '自动',
                                      en: 'Auto',
                                      tw: '自動',
                                    ),
                                    style: TextStyle(
                                      color: p.lycheeInk,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            node.latency > 0 && node.latency < 9999
                                ? v3Copy(
                                    context,
                                    zh: '延迟 ${node.latency} ms',
                                    en: 'Latency ${node.latency} ms',
                                    tw: '延遲 ${node.latency} ms',
                                  )
                                : node.latency == -1
                                ? v3Copy(
                                    context,
                                    zh: '测速中',
                                    en: 'Testing',
                                    tw: '測速中',
                                  )
                                : node.latency >= 9999
                                ? v3Copy(
                                    context,
                                    zh: '测速超时',
                                    en: 'Probe timed out',
                                    tw: '測速逾時',
                                  )
                                : v3Copy(
                                    context,
                                    zh: '未测速',
                                    en: 'Not tested',
                                    tw: '未測速',
                                  ),
                            style: TextStyle(
                              color: node.latency > 0 && node.latency < 9999
                                  ? p.successInk
                                  : p.inkMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Tags describe the resolved node, automatic or not.
                if (node.tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  V3NodeTags(tags: node.tags, maxVisible: 2),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => V3NodePicker.show(context),
                    style: OutlinedButton.styleFrom(
                      // Quiet secondary: the connect orb owns the page's pink.
                      // A full lychee outline here competed with it.
                      foregroundColor: p.ink,
                      side: BorderSide(color: p.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(V3Radius.field),
                      ),
                    ),
                    icon: Icon(Icons.swap_horiz_rounded,
                        size: 18, color: p.lychee),
                    label: Text(
                      v3Copy(
                        context,
                        zh: '切换节点',
                        en: 'Change node',
                        tw: '切換節點',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [intro, const SizedBox(height: 12), route],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: intro),
            const SizedBox(width: 12),
            Expanded(child: route),
          ],
        );
      },
    );
  }
}

class _ConnectionOrb extends StatelessWidget {
  const _ConnectionOrb({
    required this.controller,
    required this.connected,
    required this.connecting,
  });
  final AppController controller;
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final locked = controller.connectionActionLocked;
    final label = connecting
        ? v3Copy(context, zh: '正在切换连接', en: 'Changing connection', tw: '正在切換連線')
        : connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : v3Copy(context, zh: '连接', en: 'Connect', tw: '連線');
    return Semantics(
      key: kConnectOrbKey,
      button: true,
      enabled: !locked,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 86,
          height: 86,
          child: Material(
            color: connected ? p.citrus : p.lychee,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: locked
                  ? null
                  : () async {
                      // Failure remains a persistent alert with a retry action.
                      final error = await controller.toggleConnection();
                      if (error == null && context.mounted &&
                          controller.connectionStatus == ConnectionStatus.connected) {
                        V3Toast.show(context, v3Copy(context,
                          zh: '连接成功', en: 'Connected', tw: '連線成功'),
                          type: V3ToastType.success);
                      }
                    },
              child: Center(
                child: connecting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.onLychee,
                        ),
                      )
                    : Icon(
                        connected
                            ? Icons.stop_rounded
                            : Icons.power_settings_new_rounded,
                        color: connected ? p.night : p.onLychee,
                        size: 30,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Tick only the elapsed-time label, not the whole dashboard.
class _ConnectionDuration extends StatefulWidget {
  const _ConnectionDuration({required this.controller});
  final AppController controller;

  @override
  State<_ConnectionDuration> createState() => _ConnectionDurationState();
}

class _ConnectionDurationState extends State<_ConnectionDuration> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _ConnectionDuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.controller.connectionStatus == ConnectionStatus.connected) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
    _duration(widget.controller.connectedDuration),
    key: const Key('v3-connection-duration'),
    style: TextStyle(color: V3Palette.of(context).inkMuted, fontSize: 11),
  );
}

/// Hide unsupported system-proxy status from Android and Linux Home.
bool v3ShowsNetworkMode(TargetPlatform platform, NetworkMode mode) =>
    mode == NetworkMode.tun ||
    platform == TargetPlatform.windows || platform == TargetPlatform.macOS;

class _ModeRail extends StatefulWidget {
  const _ModeRail({required this.controller});
  final AppController controller;

  @override
  State<_ModeRail> createState() => _ModeRailState();
}

class _ModeRailState extends State<_ModeRail> {
  // Both rails ask the core to reload its config on switch; a second tap
  // while the first is still applying would race it. One lock covers both,
  // the same guard the connect orb gets from connectionActionLocked.
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setNetworkMode(NetworkMode mode) async {
    final controller = widget.controller;
    final error = await controller.setNetworkMode(mode);
    if (!mounted) return;
    if (error != null) {
      V3Toast.show(context, error, type: V3ToastType.error);
      return;
    }
    final label = _networkModeLabel(context, mode);
    final applied = controller.coreProcessRunning
        ? v3Copy(context,
            zh: '已切换到$label，重连后生效',
            en: 'Switched mode; reconnect to apply it',
            tw: '已切換至$label，重新連線後生效')
        : v3Copy(context,
            zh: '连接模式已切换，将在下次连接时生效',
            en: 'Mode switched. It applies on your next connection.',
            tw: '連線模式已切換，將於下次連線時生效');
    V3Toast.show(context, applied, type: V3ToastType.success);
  }

  Future<void> _setProxyMode(ProxyMode mode) async {
    final error = await widget.controller.setProxyMode(mode);
    if (!mounted) return;
    if (error != null) {
      V3Toast.show(context, error, type: V3ToastType.error);
      return;
    }
    V3Toast.show(context, v3Copy(context,
      zh: '已切换到${_modeTitle(context, mode)}',
      en: 'Switched to ${_modeTitle(context, mode)}',
      tw: '已切換至${_modeTitle(context, mode)}'),
      type: V3ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = widget.controller;
    final network = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v3Copy(context, zh: '代理模式', en: 'Network mode', tw: '代理模式'),
          style: TextStyle(
            color: p.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _ModeSegment<NetworkMode>(
          values: NetworkMode.values
              .where((mode) => v3ShowsNetworkMode(defaultTargetPlatform, mode))
              .toList(),
          label: _networkModeLabel,
          selected: controller.networkMode,
          busy: _busy,
          onSelect: (mode) => _run(() => _setNetworkMode(mode)),
          trackKey: 'v3-network-mode-track',
          optionKey: (mode) => 'v3-network-mode-${mode.storageKey}',
        ),
      ],
    );
    final routing = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v3Copy(context, zh: '路由模式', en: 'Routing mode', tw: '路由模式'),
          style: TextStyle(
            color: p.ink,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _ModeSegment<ProxyMode>(
          values: ProxyMode.values,
          label: _modeTitle,
          selected: controller.proxyMode,
          busy: _busy,
          onSelect: (mode) => _run(() => _setProxyMode(mode)),
          trackKey: 'v3-route-mode-track',
        ),
      ],
    );
    return _DashboardCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 555) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [network, const SizedBox(height: 14), routing],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: network),
              const SizedBox(width: 14),
              SizedBox(
                height: 69,
                child: VerticalDivider(color: p.line, width: 1),
              ),
              const SizedBox(width: 14),
              Expanded(child: routing),
            ],
          );
        },
      ),
    );
  }
}

/// A continuous segmented capsule: one raised track holding every option,
/// the current selection ringed in lychee — the same pink-outline language
/// as the switch-node button beside it. Both dashboard mode groups render
/// through this widget so the 2-option and 3-option groups read as one
/// control family.
class _ModeSegment<T> extends StatelessWidget {
  const _ModeSegment({required this.values, required this.label,
    required this.selected, required this.busy, required this.onSelect,
    this.trackKey, this.optionKey});
  final List<T> values;
  final String Function(BuildContext, T) label;
  final T selected;
  final bool busy;
  final ValueChanged<T> onSelect;
  final String? trackKey;
  final String Function(T)? optionKey;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      key: trackKey == null ? null : ValueKey<String>(trackKey!),
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(V3Radius.field),
      ),
      child: Row(children: [
        for (final value in values)
          Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(V3Radius.control),
            onTap: busy || value == selected ? null : () => onSelect(value),
            child: AnimatedContainer(
              key: optionKey == null
                  ? null : ValueKey<String>(optionKey!(value)),
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 13),
              // The selection keeps the track fill and gains a lychee ring —
              // an outline chip, not a solid slab of pink. The 1dp border is
              // always present (transparent when unselected) so no option
              // ever shifts by a pixel when the ring moves.
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: value == selected ? p.lychee : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(V3Radius.control),
              ),
              child: Text(
                label(context, value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: value == selected ? p.lycheeInk : p.inkMuted,
                  fontSize: 11,
                  fontWeight: selected == value
                      ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ),
          )),
      ]),
    );
  }
}

class _SessionMetrics extends StatelessWidget {
  const _SessionMetrics({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return _DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
          final compact = constraints.maxWidth < 450;
          // Traffic arrives through ValueNotifiers, not AppController.notifyListeners.
          // Subscribe here so the displayed B/s changes without a page rebuild.
          final download = ValueListenableBuilder<int>(
            valueListenable: controller.downBpsNotifier,
            builder: (context, bps, _) => _Metric(
              label: v3Copy(
                context,
                zh: '下载速度',
                en: 'Download speed',
                tw: '下載速度',
              ),
              value: _speed(bps),
              icon: Icons.arrow_downward_rounded,
              color: p.successInk,
            ),
          );
          final upload = ValueListenableBuilder<int>(
            valueListenable: controller.upBpsNotifier,
            builder: (context, bps, _) => _Metric(
              label: v3Copy(
                context,
                zh: '上传速度',
                en: 'Upload speed',
                tw: '上傳速度',
              ),
              value: _speed(bps),
              icon: Icons.arrow_upward_rounded,
              color: p.lycheeInk,
            ),
          );
          final session = ValueListenableBuilder<int>(
            valueListenable: controller.sessionBytesNotifier,
            builder: (context, bytes, _) => _Metric(
              label: v3Copy(
                context,
                zh: '本次流量',
                en: 'This session',
                tw: '本次流量',
              ),
              value: _bytes(bytes),
              icon: Icons.data_usage_rounded,
              color: p.warningInk,
            ),
          );
          final connections = ValueListenableBuilder<int>(
            valueListenable: controller.connectionsCountNotifier,
            builder: (context, count, _) => _Metric(
              label: v3Copy(
                context,
                zh: '活动连接',
                en: 'Connections',
                tw: '活動連線',
              ),
              value: '$count',
              icon: Icons.link_rounded,
              color: p.aquaInk,
            ),
          );
          // One shared cell inset keeps the four columns on the same grid:
          // every label starts at the same offset from its divider.
          Widget cell(Widget metric) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: metric,
            ),
          );
          Widget divider() => Container(width: 1, height: 38, color: p.line);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [cell(session), cell(connections)]),
                const SizedBox(height: 12),
                Row(children: [cell(download), cell(upload)]),
              ],
            );
          }
          return Row(
            children: [
              cell(session),
              divider(),
              cell(connections),
              divider(),
              cell(download),
              divider(),
              cell(upload),
            ],
          );
        },
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: p.line),
          const SizedBox(height: 10),
          _ConnectivityRow(controller: controller),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Stat tile: icon + label on a quiet line, value below, both centered.
    // The four equal zones make the centered tiles read symmetric.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: p.inkMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: p.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Connectivity line inside the live-status card: probes well-known sites
/// through the live network path so a connected user can confirm the tunnel
/// actually reaches the services they care about. Auto-runs once when the
/// connection comes up; results clear when it drops so stale greens never
/// linger.
class _ConnectivityRow extends StatefulWidget {
  const _ConnectivityRow({required this.controller});
  final AppController controller;

  @override
  State<_ConnectivityRow> createState() => _ConnectivityRowState();
}

class _ConnectivityRowState extends State<_ConnectivityRow> {
  static const _targets = ConnectivityCheckService.defaultTargets;
  // index → result; absent = not probed yet, explicit null = probing now.
  final Map<int, ConnectivityResult?> _results = {};
  bool _running = false;
  ConnectionStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _lastStatus = widget.controller.connectionStatus;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final status = widget.controller.connectionStatus;
    if (status == _lastStatus) return;
    final becameConnected =
        status == ConnectionStatus.connected &&
        _lastStatus != ConnectionStatus.connected;
    _lastStatus = status;
    if (!mounted) return;
    if (status != ConnectionStatus.connected && _results.isNotEmpty) {
      setState(_results.clear);
    }
    if (becameConnected && !_running) {
      setState(() {}); // refresh the disconnected hint
      unawaited(_runCheck());
    }
  }

  Future<void> _runCheck() async {
    if (_running) return;
    setState(() => _running = true);
    for (var i = 0; i < _targets.length; i++) {
      setState(() => _results[i] = null);
    }
    await Future.wait([
      for (var i = 0; i < _targets.length; i++)
        ConnectivityCheckService.probe(_targets[i]).then((result) {
          if (mounted) setState(() => _results[i] = result);
        }),
    ]);
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final connected =
        widget.controller.connectionStatus == ConnectionStatus.connected;
    // The refresh control rides at the end of the line so the strip stays
    // one row tall inside the live-status card.
    final refresh = _running
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            onPressed: connected ? _runCheck : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: connected ? p.lychee : p.inkMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            tooltip: v3Copy(context, zh: '重新检测', en: 'Re-check', tw: '重新檢測'),
          );
    return Row(
      children: [
        Expanded(
          child: !connected && _results.isEmpty && !_running
              ? Text(
                  v3Copy(context,
                    zh: '连接后可检测各站点连通性',
                    en: 'Connect to check site reachability',
                    tw: '連線後可檢測各站點連通性'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                )
              : Row(
                  children: [
                    for (var i = 0; i < _targets.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _ConnectivitySite(
                            target: _targets[i],
                            result: _results[i],
                            probing: _running,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(width: 6),
        refresh,
      ],
    );
  }
}

class _ConnectivitySite extends StatelessWidget {
  const _ConnectivitySite({
    required this.target,
    required this.result,
    required this.probing,
  });
  final ConnectivityTarget target;
  final ConnectivityResult? result;
  final bool probing;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final r = result;
    final dotColor = probing && r == null
        ? p.warning
        : r == null
        ? p.line
        : r.ok
        ? p.success
        : p.danger;
    final statusLine = probing && r == null
        ? v3Copy(context, zh: '检测中', en: 'Probing', tw: '檢測中')
        : r == null
        ? v3Copy(context, zh: '未检测', en: 'Not probed', tw: '未檢測')
        : r.ok
        ? '${r.latencyMs} ms'
        : v3Copy(context, zh: '不通', en: 'Blocked', tw: '不通');
    final statusColor = probing && r == null
        ? p.warningInk
        : r == null
        ? p.inkMuted
        : r.ok
        ? p.successInk
        : p.dangerInk;
    // Inline tile: dot, site name and status share one line so four sites
    // fit beside the refresh control without crowding.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            target.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 10,
              fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusLine,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: statusColor, fontSize: 10),
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final plan = PlanPresentation.fromController(controller);
    final total = controller.traffic.totalGb;
    final used = controller.traffic.usedGb;
    final ratio = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    // Countdown only from real expiry evidence, resolved exactly like the
    // card's own date label (subscription first, then account); a permanent
    // plan (null/0 expiry) and an unevidenced plan never get one.
    final expiryEpoch = PlanPresentation.expiryTimestampWithEvidence(
      accountExpiry: controller.accountDetails?.expiredAt,
      subscriptionExpiry: controller.expiredAt,
    );
    String? countdown;
    var expiryUrgent = false;
    if (plan.usable && expiryEpoch != null && expiryEpoch > 0) {
      final remaining = DateTime.fromMillisecondsSinceEpoch(
        expiryEpoch * 1000,
      ).difference(DateTime.now());
      if (remaining.inSeconds > 0) {
        final days = remaining.inDays;
        countdown = days >= 1
            ? v3Copy(
                context,
                zh: '剩余 $days 天',
                en: '$days days left',
                tw: '剩餘 $days 天',
              )
            : v3Copy(
                context,
                zh: '今日到期',
                en: 'Expires today',
                tw: '今日到期',
              );
        expiryUrgent = remaining.inDays < 3;
      }
    }
    return _DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header mirrors the current-node card: title left, the status
          // token (days countdown) right where that card shows its badge.
          Row(
            children: [
              Expanded(
                child: Text(
                  v3Copy(context, zh: '我的套餐', en: 'My plan', tw: '我的方案'),
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (countdown != null)
                Text(
                  countdown,
                  style: TextStyle(
                    color: expiryUrgent ? p.dangerInk : p.successInk,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: BorderRadius.circular(V3Radius.field),
                ),
                child: Icon(Icons.diamond_outlined, color: p.citrus, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.expiry} · ${plan.status}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: plan.usable ? p.successInk : p.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(V3Radius.card),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 9,
                color: p.success,
                backgroundColor: p.surfaceRaised,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(
                    v3Copy(
                      context,
                      zh: '已用 ${used.toStringAsFixed(1)} GB / 共 ${total.toStringAsFixed(1)} GB',
                      en: '${used.toStringAsFixed(1)} GB used / ${total.toStringAsFixed(1)} GB',
                      tw: '已用 ${used.toStringAsFixed(1)} GB / 共 ${total.toStringAsFixed(1)} GB',
                    ),
                    style: TextStyle(color: p.inkMuted, fontSize: 10),
                  ),
                ),
                Text(
                  v3Copy(
                    context,
                    zh: '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                    en: '${controller.traffic.remainGb.toStringAsFixed(1)} GB left',
                    tw: '剩餘 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                  ),
                  style: TextStyle(color: p.ink, fontSize: 10),
                ),
              ],
            ),
          ] else
            Text(
              v3Copy(
                context,
                zh: '暂无流量数据',
                en: 'No traffic data',
                tw: '暫無流量資料',
              ),
              style: TextStyle(color: p.inkMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

String _statusLabel(BuildContext context, ConnectionStatus status) =>
    switch (status) {
      ConnectionStatus.connected => v3Copy(
        context,
        zh: '已连接',
        en: 'Connected',
        tw: '已連線',
      ),
      ConnectionStatus.connecting || ConnectionStatus.disconnecting => v3Copy(
        context,
        zh: '处理中',
        en: 'Processing',
        tw: '處理中',
      ),
      ConnectionStatus.error => v3Copy(
        context,
        zh: '连接异常',
        en: 'Connection error',
        tw: '連線異常',
      ),
      ConnectionStatus.disconnected => v3Copy(
        context,
        zh: '未连接',
        en: 'Disconnected',
        tw: '未連線',
      ),
    };

String _modeTitle(BuildContext context, ProxyMode mode) => switch (mode) {
  ProxyMode.rule => v3Copy(context, zh: '规则', en: 'Rules', tw: '規則'),
  ProxyMode.global => v3Copy(context, zh: '全局', en: 'Global', tw: '全域'),
  ProxyMode.direct => v3Copy(context, zh: '直连', en: 'Direct', tw: '直連'),
};
String _networkModeLabel(BuildContext context, NetworkMode mode) => v3Copy(
  context,
  zh: mode == NetworkMode.tun ? 'TUN 模式' : '系统代理',
  en: mode == NetworkMode.tun ? 'TUN mode' : 'System proxy',
  tw: mode == NetworkMode.tun ? 'TUN 模式' : '系統代理',
);

String _speed(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB/s';
  return '$value B/s';
}

/// Human-readable session usage: bytes → KB → MB → GB. Zero reads as
/// "0 MB" — the byte tier only ever shows before the core has moved anything,
/// and MB is the unit people actually expect on a usage gauge.
String _bytes(int value) {
  if (value >= 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (value > 0) return '${(value / 1024).toStringAsFixed(value < 10240 ? 1 : 0)} KB';
  return '0 MB';
}

String _duration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

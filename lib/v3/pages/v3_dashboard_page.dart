import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../app/plan_presentation.dart';
import '../../shared/models/app_models.dart';
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
                  backgroundColor: p.lychee, foregroundColor: Colors.white,
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
    final displayName = controller.autoSelected
        ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
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
              borderRadius: BorderRadius.circular(17),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: V3NodeFlag(code: node.code),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
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
                if (!controller.autoSelected && node.tags.isNotEmpty) ...[
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
                      foregroundColor: p.lycheeInk,
                      side: BorderSide(color: p.lychee),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
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
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        connected
                            ? Icons.stop_rounded
                            : Icons.power_settings_new_rounded,
                        color: connected ? p.night : Colors.white,
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

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
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
        Row(
          children: [
            for (final mode in NetworkMode.values)
              if (v3ShowsNetworkMode(defaultTargetPlatform, mode)) Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode == NetworkMode.values.last ? 0 : 7,
                  ),
              child: _NetworkModeIndicator(
                    controller: controller,
                    mode: mode,
                  ),
                ),
              ),
          ],
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
        Row(
          children: [
            for (final mode in ProxyMode.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode == ProxyMode.values.last ? 0 : 6,
                  ),
                  child: _RouteButton(controller: controller, mode: mode),
                ),
              ),
          ],
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

class _NetworkModeIndicator extends StatelessWidget {
  const _NetworkModeIndicator({required this.controller, required this.mode});
  final AppController controller;
  final NetworkMode mode;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final selected = controller.networkMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      // The mode pill now behaves like the routing pills beside it: tap the
      // mode you want. Switching reloads the core config, so failures surface
      // as a SnackBar and success as a toast — same contract as _RouteButton.
      onTap: selected ? null : () async {
        final error = await controller.setNetworkMode(mode);
        if (!context.mounted) return;
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error)));
        } else {
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
      },
      child: Container(
        key: ValueKey('v3-network-mode-${mode.storageKey}'),
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
        decoration: BoxDecoration(
          // Configured modes are a selection, not a connectivity health signal.
          // Follow the plan-cycle style rather than tinting the white label green.
          color: selected ? p.lycheeSoft : p.surfaceRaised,
          border: Border.all(color: selected ? p.lychee : p.line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          _networkModeLabel(context, mode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? p.lycheeInk : p.inkMuted,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({required this.controller, required this.mode});
  final AppController controller;
  final ProxyMode mode;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final active = controller.proxyMode == mode;
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: () async {
          if (active) return;
          final error = await controller.setProxyMode(mode);
          if (!context.mounted) return;
          if (error != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error)));
          } else {
            V3Toast.show(context, v3Copy(context,
              zh: '已切换到${_modeTitle(context, mode)}',
              en: 'Switched to ${_modeTitle(context, mode)}',
              tw: '已切換至${_modeTitle(context, mode)}'),
              type: V3ToastType.success);
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          foregroundColor: active ? p.lycheeInk : p.ink,
          backgroundColor: active ? p.lycheeSoft : Colors.transparent,
          side: BorderSide(color: active ? p.lychee : p.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(
          _modeTitle(context, mode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 450;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                v3Copy(context, zh: '实时速度', en: 'Live speed', tw: '即時速度'),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                v3Copy(
                  context,
                  zh: '当前网络传输速率',
                  en: 'Current transfer rate',
                  tw: '目前網路傳輸速率',
                ),
                style: TextStyle(color: p.inkMuted, fontSize: 10),
              ),
            ],
          );
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
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 12),
                download,
                const SizedBox(height: 10),
                upload,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              Expanded(child: download),
              Container(width: 1, height: 38, color: p.line),
              Expanded(child: upload),
            ],
          );
        },
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.inkMuted, fontSize: 10),
              ),
              const SizedBox(height: 4),
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
          ),
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
    return _DashboardCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.diamond_outlined, color: p.citrus, size: 23),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v3Copy(context, zh: '我的套餐', en: 'My plan', tw: '我的方案'),
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
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
                    const SizedBox(height: 3),
                    Text(
                      plan.status,
                      style: TextStyle(
                        color: plan.usable ? p.successInk : p.inkMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  plan.expiry,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
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

String _duration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

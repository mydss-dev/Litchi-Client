import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../app/plan_presentation.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_notice_bar.dart';
import '../ui/v3_update_banner.dart';

/// One connection page: the desktop rail must never add a second Home route.
class V3DashboardPage extends StatelessWidget {
  const V3DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final status = controller.connectionStatus;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const V3UpdateBanner(),
        V3NoticeBar(controller: controller),
        _ConnectionWorkspace(controller: controller,
          connected: status == ConnectionStatus.connected,
          connecting: status == ConnectionStatus.connecting ||
            status == ConnectionStatus.disconnecting),
        const SizedBox(height: 12),
        _ModeRail(controller: controller),
        const SizedBox(height: 12),
        _SessionMetrics(controller: controller),
        const SizedBox(height: 12),
        _PlanSummary(controller: controller),
      ]),
    );
  }
}

/// A near-black local surface in dark mode; light mode keeps its own palette.
/// Do not replace the app canvas with the gray-green mockup background.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? p.hero : p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

const kConnectActionCardKey = Key('v3-connect-action-card');
const kCurrentNodeCardKey = Key('v3-current-node-card');
const kConnectOrbKey = Key('v3-connect-orb');

class _ConnectionWorkspace extends StatelessWidget {
  const _ConnectionWorkspace({required this.controller,
    required this.connected, required this.connecting});
  final AppController controller;
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final statusColor = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting || ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.inkMuted,
    };
    final error = status == ConnectionStatus.error
      ? controller.coreError.isEmpty
        ? v3Copy(context, zh: '请重试连接，或切换其他节点。',
            en: 'Retry or change nodes.', tw: '請重試或切換節點。')
        : controller.coreError
      : null;
    final node = controller.currentNode;
    final displayName = controller.autoSelected
      ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
      : node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点',
            en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = constraints.maxWidth < 500;
      final cardHeight = stacked ? 224.0 : 236.0;
      final intro = SizedBox(
        key: kConnectActionCardKey,
        height: cardHeight,
        child: _DashboardCard(padding: EdgeInsets.zero,
          child: ClipRRect(borderRadius: BorderRadius.circular(17),
            child: Stack(children: [
              Positioned.fill(child: IgnorePointer(child: Opacity(
                opacity: Theme.of(context).brightness == Brightness.dark
                    ? .065 : .035,
                child: SvgPicture.asset('assets/images/world_coastline.svg',
                  fit: BoxFit.contain),
              ))),
              Positioned.fill(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v3Copy(context, zh: '连接状态',
                      en: 'Connection', tw: '連線狀態'),
                      style: TextStyle(color: p.ink, fontSize: 14,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(_statusLabel(context, status),
                      style: TextStyle(color: statusColor, fontSize: 11)),
                    Expanded(child: Center(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ConnectionOrb(controller: controller,
                          connected: connected, connecting: connecting),
                        const SizedBox(height: 9),
                        Text(connected
                          ? v3Copy(context, zh: '断开连接',
                              en: 'Disconnect', tw: '中斷連線')
                          : connecting
                            ? v3Copy(context, zh: '处理中',
                                en: 'Processing', tw: '處理中')
                            : v3Copy(context, zh: '点击开始连接',
                                en: 'Tap to connect', tw: '點擊開始連線'),
                          style: TextStyle(color: p.ink, fontSize: 12,
                            fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(_duration(controller.connectedDuration),
                          style: TextStyle(color: p.inkMuted, fontSize: 11)),
                        if (error != null) ...[
                          const SizedBox(height: 4),
                          Text(error, maxLines: 2, overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.dangerInk, fontSize: 10)),
                        ],
                      ],
                    ))),
                  ],
                ),
              )),
            ]),
          ),
        ),
      );
      final route = SizedBox(
        key: kCurrentNodeCardKey,
        height: cardHeight,
        child: _DashboardCard(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(v3Copy(context, zh: '当前节点',
                  en: 'Current node', tw: '目前節點'),
                  style: TextStyle(color: p.ink, fontSize: 14,
                    fontWeight: FontWeight.w800))),
                V3StatusBadge(label: _statusLabel(context, status),
                  color: statusColor),
              ]),
              const SizedBox(height: 15),
              Row(children: [
                Container(width: 42, height: 42, alignment: Alignment.center,
                  decoration: BoxDecoration(color: p.surfaceRaised,
                    borderRadius: BorderRadius.circular(12)),
                  child: V3NodeFlag(code: node.code)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.ink, fontSize: 15,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(node.latency > 0 && node.latency < 9999
                      ? v3Copy(context, zh: '延迟 ${node.latency} ms',
                          en: 'Latency ${node.latency} ms',
                          tw: '延遲 ${node.latency} ms')
                      : node.latency >= 9999
                        ? v3Copy(context, zh: '测速超时',
                            en: 'Probe timed out', tw: '測速逾時')
                        : v3Copy(context, zh: '未测速',
                            en: 'Not tested', tw: '未測速'),
                      style: TextStyle(color: node.latency > 0 &&
                        node.latency < 9999 ? p.successInk : p.inkMuted,
                        fontSize: 11)),
                  ],
                )),
              ]),
              const Spacer(),
              SizedBox(width: double.infinity, height: 44,
                child: OutlinedButton.icon(
                  onPressed: () => V3NodePicker.show(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.lycheeInk,
                    side: BorderSide(color: p.lychee),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(v3Copy(context, zh: '切换节点',
                    en: 'Change node', tw: '切換節點')),
                ),
              ),
            ],
          ),
        ),
      );
      if (stacked) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [intro, const SizedBox(height: 12), route]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: intro),
        const SizedBox(width: 12),
        Expanded(child: route),
      ]);
    });
  }
}

class _ConnectionOrb extends StatelessWidget {
  const _ConnectionOrb({required this.controller,
    required this.connected, required this.connecting});
  final AppController controller;
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final locked = controller.connectionActionLocked;
    final label = connecting
      ? v3Copy(context, zh: '正在切换连接',
          en: 'Changing connection', tw: '正在切換連線')
      : connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : v3Copy(context, zh: '连接', en: 'Connect', tw: '連線');
    return Semantics(key: kConnectOrbKey, button: true,
      enabled: !locked, label: label,
      child: ExcludeSemantics(child: SizedBox(width: 86, height: 86,
        child: Material(
          color: connected ? p.citrus : p.lychee,
          shape: const CircleBorder(),
          child: InkWell(customBorder: const CircleBorder(),
            onTap: locked ? null : () async {
              final error = await controller.toggleConnection();
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)));
              }
            },
            child: Center(child: connecting
              ? const SizedBox(width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2,
                    color: Colors.white))
              : Icon(connected ? Icons.stop_rounded
                  : Icons.power_settings_new_rounded,
                  color: connected ? p.night : Colors.white, size: 30)),
          ),
        ),
      )),
    );
  }
}

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final network = Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v3Copy(context, zh: '代理模式', en: 'Network mode',
          tw: '代理模式'),
          style: TextStyle(color: p.ink, fontSize: 12,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          for (final mode in NetworkMode.values)
            Expanded(child: Padding(
              padding: EdgeInsets.only(right:
                mode == NetworkMode.values.last ? 0 : 7),
              child: _NetworkModeIndicator(mode: mode,
                selected: controller.networkMode == mode))),
        ]),
      ],
    );
    final routing = Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(v3Copy(context, zh: '路由模式', en: 'Routing mode',
          tw: '路由模式'),
          style: TextStyle(color: p.ink, fontSize: 12,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Row(children: [
          for (final mode in ProxyMode.values)
            Expanded(child: Padding(
              padding: EdgeInsets.only(right:
                mode == ProxyMode.values.last ? 0 : 6),
              child: _RouteButton(controller: controller, mode: mode))),
        ]),
      ],
    );
    return _DashboardCard(padding: const EdgeInsets.all(14),
      child: LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 555) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [network, const SizedBox(height: 14), routing]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: network),
          const SizedBox(width: 14),
          SizedBox(height: 69, child: VerticalDivider(color: p.line, width: 1)),
          const SizedBox(width: 14),
          Expanded(child: routing),
        ]);
      }),
    );
  }
}

class _NetworkModeIndicator extends StatelessWidget {
  const _NetworkModeIndicator({required this.mode, required this.selected});
  final NetworkMode mode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
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
      child: Text(_networkModeLabel(context, mode),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(color: selected ? p.lycheeInk : p.inkMuted,
          fontSize: 10, fontWeight: selected ? FontWeight.w800
            : FontWeight.w500)),
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
    return SizedBox(height: 44, child: OutlinedButton(
      onPressed: () async {
        final error = await controller.setProxyMode(mode);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error)));
        }
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        foregroundColor: active ? p.lycheeInk : p.ink,
        backgroundColor: active ? p.lycheeSoft : Colors.transparent,
        side: BorderSide(color: active ? p.lychee : p.line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11))),
      child: Text(_modeTitle(context, mode),
        maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ));
  }
}

class _SessionMetrics extends StatelessWidget {
  const _SessionMetrics({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return _DashboardCard(padding: const EdgeInsets.all(14),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 450;
        final heading = Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v3Copy(context, zh: '实时速度', en: 'Live speed',
              tw: '即時速度'),
              style: TextStyle(color: p.ink, fontSize: 12,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(v3Copy(context, zh: '当前网络传输速率',
              en: 'Current transfer rate', tw: '目前網路傳輸速率'),
              style: TextStyle(color: p.inkMuted, fontSize: 10)),
          ],
        );
        final download = _Metric(label: v3Copy(context, zh: '下载速度',
          en: 'Download speed', tw: '下載速度'),
          value: _speed(controller.downBps),
          icon: Icons.arrow_downward_rounded, color: p.successInk);
        final upload = _Metric(label: v3Copy(context, zh: '上传速度',
          en: 'Upload speed', tw: '上傳速度'),
          value: _speed(controller.upBps),
          icon: Icons.arrow_upward_rounded, color: p.lycheeInk);
        if (compact) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 12),
              download, const SizedBox(height: 10), upload]);
        }
        return Row(children: [
          Expanded(child: heading),
          Expanded(child: download),
          Container(width: 1, height: 38, color: p.line),
          Expanded(child: upload),
        ]);
      }),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value,
    required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.inkMuted, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 14,
              fontWeight: FontWeight.w800)),
        ],
      )),
    ]);
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
    return _DashboardCard(padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.diamond_outlined, color: p.citrus, size: 23),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v3Copy(context, zh: '我的套餐',
                  en: 'My plan', tw: '我的方案'),
                  style: TextStyle(color: p.ink, fontSize: 12,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(plan.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.ink, fontSize: 15,
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(plan.status,
                  style: TextStyle(color: plan.usable
                    ? p.successInk : p.inkMuted, fontSize: 10)),
              ],
            )),
            const SizedBox(width: 10),
            Flexible(child: Text(plan.expiry, textAlign: TextAlign.end,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.inkMuted, fontSize: 11))),
          ]),
          const SizedBox(height: 13),
          if (total > 0) ...[
            ClipRRect(borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: ratio, minHeight: 9, color: p.success,
                backgroundColor: p.surfaceRaised)),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: Text(v3Copy(context,
                zh: '已用 ${used.toStringAsFixed(1)} GB / 共 ${total.toStringAsFixed(1)} GB',
                en: '${used.toStringAsFixed(1)} GB used / ${total.toStringAsFixed(1)} GB',
                tw: '已用 ${used.toStringAsFixed(1)} GB / 共 ${total.toStringAsFixed(1)} GB'),
                style: TextStyle(color: p.inkMuted, fontSize: 10))),
              Text(v3Copy(context,
                zh: '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                en: '${controller.traffic.remainGb.toStringAsFixed(1)} GB left',
                tw: '剩餘 ${controller.traffic.remainGb.toStringAsFixed(1)} GB'),
                style: TextStyle(color: p.ink, fontSize: 10)),
            ]),
          ] else
            Text(v3Copy(context, zh: '暂无流量数据',
              en: 'No traffic data', tw: '暫無流量資料'),
              style: TextStyle(color: p.inkMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

String _statusLabel(BuildContext context, ConnectionStatus status) =>
    switch (status) {
  ConnectionStatus.connected => v3Copy(context, zh: '已连接',
    en: 'Connected', tw: '已連線'),
  ConnectionStatus.connecting || ConnectionStatus.disconnecting =>
    v3Copy(context, zh: '处理中', en: 'Processing', tw: '處理中'),
  ConnectionStatus.error => v3Copy(context, zh: '连接异常',
    en: 'Connection error', tw: '連線異常'),
  ConnectionStatus.disconnected => v3Copy(context, zh: '未连接',
    en: 'Disconnected', tw: '未連線'),
};

String _modeTitle(BuildContext context, ProxyMode mode) => switch (mode) {
  ProxyMode.rule => v3Copy(context, zh: '规则', en: 'Rules', tw: '規則'),
  ProxyMode.global => v3Copy(context, zh: '全局', en: 'Global', tw: '全域'),
  ProxyMode.direct => v3Copy(context, zh: '直连', en: 'Direct', tw: '直連'),
};
String _networkModeLabel(BuildContext context, NetworkMode mode) =>
    v3Copy(context,
      zh: mode == NetworkMode.tun ? 'TUN 模式' : '系统代理',
      en: mode == NetworkMode.tun ? 'TUN mode' : 'System proxy',
      tw: mode == NetworkMode.tun ? 'TUN 模式' : '系統代理');

String _speed(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB/s';
  return '$value B/s';
}

String _duration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
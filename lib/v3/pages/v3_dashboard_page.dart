import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../ui/v3_components.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_notice_bar.dart';
import '../ui/v3_update_banner.dart';

class V3DashboardPage extends StatelessWidget {
  const V3DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final connected = status == ConnectionStatus.connected;
    final connecting =
        status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final statusColor = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.inkMuted,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V3PageHeader(
            kicker: '连接中心',
            title: '连接',
            description: '选择节点与代理模式，开始连接。',
            trailing: V3StatusBadge(
              label: _statusLabel(status),
              color: statusColor,
            ),
          ),
          const SizedBox(height: 16),
          // Both render nothing at all when there is nothing to say, and each
          // carries its own bottom gap, so their absence collapses cleanly
          // instead of leaving a hole where news used to be.
          const V3UpdateBanner(),
          V3NoticeBar(controller: controller),
          _ConnectionWorkspace(
            controller: controller,
            connected: connected,
            connecting: connecting,
          ),
          const SizedBox(height: 14),
          _ModeRail(controller: controller),
          const SizedBox(height: 14),
          _SessionMetrics(controller: controller),
          const SizedBox(height: 14),
          _PlanSummary(controller: controller),
        ],
      ),
    );
  }
}

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
    final node = controller.currentNode;
    final actionLabel = connected
        ? '断开连接'
        : connecting
        ? '处理中'
        : '开始连接';
    // The workspace used to open with a status dot, a "连接状态" kicker, a
    // one-line verdict ("连接已建立") and a second line explaining it. The badge
    // in the page header already names the state and the orb caption already
    // names the action, so all four lines said what two other places said
    // first. What has no other home is the core's own error text.
    final error = controller.connectionStatus == ConnectionStatus.error
        ? (controller.coreError.isEmpty
              ? '请重试连接，或切换其他节点。'
              : controller.coreError)
        : null;
    return V3Panel(
      tone: V3PanelTone.hero,
      padding: const EdgeInsets.all(24),
      radius: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 500;
          final intro = Column(
            mainAxisSize: MainAxisSize.min,
            // Orb, action, elapsed time — one centred stack, so the primary
            // control sits over the middle of its own column instead of
            // hanging off the left edge under two paragraphs of prose.
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ConnectionOrb(
                controller: controller,
                connected: connected,
                connecting: connecting,
              ),
              const SizedBox(height: 14),
              Text(
                actionLabel,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _duration(controller.connectedDuration),
                style: TextStyle(color: p.inkMuted, fontSize: 12),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.dangerInk,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          );
          final route = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前节点',
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    V3NodeFlag(code: node.code),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        controller.autoSelected
                            ? '自动选择'
                            : (node.name.isEmpty ? '尚未选择节点' : node.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _NodeMeta(
                      label: node.latency > 0 && node.latency < 9999
                          ? '${node.latency} ms'
                          : '未测速',
                    ),
                    _NodeMeta(label: controller.networkMode.label),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  // Opens the picker over this page rather than navigating to
                  // the nodes page: switching a node is a choice made while
                  // looking at the connection it affects, and the full page
                  // (search, regions, 测速) is still one tab away.
                  onPressed: () => V3NodePicker.show(context),
                  style: TextButton.styleFrom(foregroundColor: p.lycheeInk),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('切换节点'),
                ),
              ],
            ),
          );
          return stacked
              ? Column(
                  // Stretch so the centred orb stack has the full width to
                  // centre within on a phone, the same place it sits on a
                  // desktop.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 16), route],
                )
              : Row(
                  // Centre, not start: the node card is the taller of the two,
                  // so the orb stack rides the middle of it rather than the top.
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 22),
                    Expanded(child: route),
                  ],
                );
        },
      ),
    );
  }
}

/// Identifies the connect orb for tests. It is an icon-only control, and the
/// caption beside it carries the same words — so there is no text to find it by
/// that would not also match the caption.
const kConnectOrbKey = Key('v3-connect-orb');

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
    // The primary action of the whole page is an icon with no text, so a screen
    // reader reached an unlabelled button: pressing it was a guess, and while a
    // connection change was in flight it did not even announce that it was
    // unavailable. The label names the action, not the glyph.
    final label = connecting
        ? '正在切换连接'
        : connected
        ? '断开连接'
        : '连接';
    return Semantics(
      key: kConnectOrbKey,
      button: true,
      enabled: !locked,
      label: label,
      // The glyph contributes nothing to announce, so the label above is the
      // whole story rather than one half of a doubled reading.
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
                      final error = await controller.toggleConnection();
                      if (error != null && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
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

class _ModeRail extends StatelessWidget {
  const _ModeRail({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return V3Panel(
      tone: V3PanelTone.raised,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: ProxyMode.values.map((mode) {
          final selected = controller.proxyMode == mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final error = await controller.setProxyMode(mode);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? p.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _modeTitle(mode),
                      style: TextStyle(
                        color: selected ? p.lycheeInk : p.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _modeHint(mode),
                      style: TextStyle(color: p.inkMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SessionMetrics extends StatelessWidget {
  const _SessionMetrics({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      // Elapsed time lives under the orb, where it belongs to the connection it
      // measures. It used to be a third cell here as well — the same clock,
      // ticking in two places on one screen, a few centimetres apart.
      final metrics = [
        _Metric(
          label: '下载速度',
          value: _speed(controller.downBps),
          icon: Icons.arrow_downward_rounded,
          compact: compact,
        ),
        _Metric(
          label: '上传速度',
          value: _speed(controller.upBps),
          icon: Icons.arrow_upward_rounded,
          compact: compact,
        ),
      ];
      return V3Panel(
        tone: V3PanelTone.surface,
        padding: EdgeInsets.zero,
        child: compact
            ? Column(
                children: [
                  metrics[0],
                  const _MetricDivider(horizontal: true),
                  metrics[1],
                ],
              )
            : Row(
                children: [
                  Expanded(child: metrics[0]),
                  const _MetricDivider(),
                  Expanded(child: metrics[1]),
                ],
              ),
      );
    },
  );
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({this.horizontal = false});

  final bool horizontal;

  @override
  Widget build(BuildContext context) => Container(
    width: horizontal ? double.infinity : 1,
    height: horizontal ? 1 : 42,
    color: V3Palette.of(context).line,
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.compact,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 14,
        vertical: compact ? 14 : 18,
      ),
      child: Row(
        mainAxisAlignment: compact
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(icon, color: p.lychee, size: 18),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final total = controller.traffic.totalGb;
    final used = controller.traffic.usedGb;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    final user = controller.user;
    return V3Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.hasPlan
                          ? (user.plan.trim().isEmpty ? '已激活套餐' : user.plan)
                          : '暂无套餐',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      total > 0
                          ? '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB'
                          : '暂无流量数据',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Text(
                controller.hasPlan
                    ? '到期 ${controller.planExpiryLabel}'
                    : '尚未开通套餐',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              color: p.lychee,
              backgroundColor: p.surfaceRaised,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              total > 0
                  ? '已用 ${used.toStringAsFixed(1)} GB / 共 ${total.toStringAsFixed(1)} GB'
                  : '选择套餐后开始使用',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small fact about the node — its latency, the proxy mode — as a chip.
///
/// Named for the dark panel it used to sit on; the panel is light now and the
/// name would be the only thing left saying otherwise.
class _NodeMeta extends StatelessWidget {
  const _NodeMeta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: p.ink,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _statusLabel(ConnectionStatus status) => switch (status) {
  ConnectionStatus.connected => '已连接',
  ConnectionStatus.connecting || ConnectionStatus.disconnecting => '处理中',
  ConnectionStatus.error => '连接异常',
  ConnectionStatus.disconnected => '未连接',
};

String _modeTitle(ProxyMode mode) => switch (mode) {
  ProxyMode.rule => '规则',
  ProxyMode.global => '全局',
  ProxyMode.direct => '直连',
};

String _modeHint(ProxyMode mode) => switch (mode) {
  ProxyMode.rule => '按规则分流',
  ProxyMode.global => '全部使用代理',
  ProxyMode.direct => '全部直接连接',
};

String _speed(int value) {
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB/s';
  return '$value B/s';
}

String _duration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

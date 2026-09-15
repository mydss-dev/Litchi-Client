import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';

class V3DashboardPage extends StatelessWidget {
  const V3DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final p = V3Palette.of(context);
    final connected = controller.connectionStatus == ConnectionStatus.connected;
    final connecting = controller.connectionStatus == ConnectionStatus.connecting;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(compact ? 20 : 34, 26, compact ? 20 : 34, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CONTROL DECK', style: TextStyle(color: p.accent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.2)),
                        const SizedBox(height: 7),
                        Text('连接中心', style: Theme.of(context).textTheme.displayLarge),
                      ],
                    ),
                  ),
                  _StatusPill(connected: connected, connecting: connecting),
                ],
              ),
              const SizedBox(height: 28),
              compact
                  ? Column(
                      children: [
                        _ConnectionHero(controller: controller),
                        const SizedBox(height: 16),
                        _NodePanel(controller: controller),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 12, child: _ConnectionHero(controller: controller)),
                        const SizedBox(width: 16),
                        Expanded(flex: 8, child: _NodePanel(controller: controller)),
                      ],
                    ),
              const SizedBox(height: 16),
              _ModeDeck(controller: controller),
              const SizedBox(height: 16),
              compact
                  ? Column(
                      children: [
                        _MetricStrip(controller: controller),
                        const SizedBox(height: 16),
                        _SubscriptionStrip(controller: controller),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _MetricStrip(controller: controller)),
                        const SizedBox(width: 16),
                        Expanded(child: _SubscriptionStrip(controller: controller)),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final connected = controller.connectionStatus == ConnectionStatus.connected;
    final connecting = controller.connectionStatus == ConnectionStatus.connecting;
    final label = connecting ? '正在建立链路' : connected ? '网络已接管' : '准备连接';
    final sub = connecting
        ? 'Litchi 正在准备本地核心与网络路由'
        : connected
            ? '流量已通过当前 Litchi 节点转发'
            : '点击主控按钮开始新的网络会话';

    return Container(
      constraints: const BoxConstraints(minHeight: 292),
      decoration: BoxDecoration(
        color: p.rail,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(26),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: p.accent.withValues(alpha: 0.42), width: 18),
              ),
            ),
          ),
          Positioned(
            right: 72,
            bottom: 12,
            child: Container(
              width: 78,
              height: 8,
              decoration: BoxDecoration(color: p.cyan, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SESSION 01', style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.8)),
              const Spacer(),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              const SizedBox(height: 8),
              Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 12)),
              const SizedBox(height: 24),
              Row(
                children: [
                  SizedBox(
                    height: 58,
                    width: 58,
                    child: FilledButton(
                      onPressed: controller.connectionActionLocked
                          ? null
                          : () async {
                              final error = await controller.toggleConnection();
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: connected ? Colors.white : p.accent,
                        foregroundColor: connected ? p.rail : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: connecting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(connected ? Icons.stop_rounded : Icons.power_settings_new_rounded, size: 25),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(connected ? 'DISCONNECT' : 'CONNECT', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      const SizedBox(height: 3),
                      Text(_duration(controller.connectedDuration), style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodePanel extends StatelessWidget {
  const _NodePanel({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final node = controller.currentNode;
    return Container(
      constraints: const BoxConstraints(minHeight: 292),
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(30), border: Border.all(color: p.border)),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ACTIVE ROUTE', style: TextStyle(color: p.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded, color: p.textMuted, size: 18),
            ],
          ),
          const Spacer(),
          Text(node.flag.isEmpty ? '◎' : node.flag, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(controller.autoSelected ? '自动选择' : node.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(node.englishName.isNotEmpty ? node.englishName : 'Smart route selected by Litchi', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Row(
            children: [
              _MiniTag(text: node.latency > 0 && node.latency < 9999 ? '${node.latency} ms' : '-- ms'),
              const SizedBox(width: 8),
              _MiniTag(text: controller.networkMode.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeDeck extends StatelessWidget {
  const _ModeDeck({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(22), border: Border.all(color: p.border)),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: ProxyMode.values.map((mode) {
          final selected = controller.proxyMode == mode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final error = await controller.setProxyMode(mode);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                decoration: BoxDecoration(
                  color: selected ? p.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(_modeTitle(mode), style: TextStyle(color: selected ? p.accent : p.text, fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(_modeHint(mode), style: TextStyle(color: p.textMuted, fontSize: 10)),
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

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      height: 112,
      decoration: BoxDecoration(color: p.panelStrong, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(child: _Metric(label: 'DOWN', value: _speed(controller.downBps), icon: Icons.south_rounded, color: p.cyan)),
          Container(width: 1, height: 42, color: p.border),
          Expanded(child: _Metric(label: 'UP', value: _speed(controller.upBps), icon: Icons.north_rounded, color: p.accent)),
        ],
      ),
    );
  }
}

class _SubscriptionStrip extends StatelessWidget {
  const _SubscriptionStrip({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final total = controller.traffic.totalGb;
    final used = controller.traffic.usedGb;
    final ratio = total <= 0 ? 0.0 : (used / total).clamp(0.0, 1.0);
    return Container(
      height: 112,
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.border)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('PLAN FLOW', style: TextStyle(color: p.textMuted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Spacer(),
            Text('${controller.traffic.remainGb.toStringAsFixed(1)} GB', style: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: p.panelStrong, valueColor: AlwaysStoppedAnimation(p.accent)),
          ),
          const SizedBox(height: 9),
          Text(total > 0 ? '${used.toStringAsFixed(1)} / ${total.toStringAsFixed(1)} GB 已使用' : '暂无套餐流量数据', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon, required this.color});
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
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: p.textMuted, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: p.panelStrong, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: TextStyle(color: p.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connected, required this.connecting});
  final bool connected;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final color = connected ? p.success : connecting ? p.warning : p.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: p.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(connecting ? 'CONNECTING' : connected ? 'ONLINE' : 'STANDBY', style: TextStyle(color: p.text, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      ]),
    );
  }
}

String _modeTitle(ProxyMode mode) => switch (mode) {
      ProxyMode.rule => 'Rule',
      ProxyMode.global => 'Global',
      ProxyMode.direct => 'Direct',
    };

String _modeHint(ProxyMode mode) => switch (mode) {
      ProxyMode.rule => '智能分流',
      ProxyMode.global => '全部代理',
      ProxyMode.direct => '全部直连',
    };

String _speed(int bytesPerSecond) {
  if (bytesPerSecond >= 1024 * 1024) return '${(bytesPerSecond / 1024 / 1024).toStringAsFixed(1)} MB/s';
  if (bytesPerSecond >= 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
  return '$bytesPerSecond B/s';
}

String _duration(Duration d) {
  final h = d.inHours.toString().padLeft(2, '0');
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}

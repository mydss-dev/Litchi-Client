import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show ValueListenable;

import '../../app/core_controller.dart' show ConnectionStatus;
import '../theme/v3_luxury_tokens.dart';
import 'v3_locale_copy.dart';
import 'v3_luxury_surface.dart';
import 'v3_components.dart';

/// The source-of-truth visual states are the six extra screenshots in the
/// second design-spec archive (three status variants in both themes).
/// This widget is purely presentational. VPN core, command handling and
/// route selection remain the responsibilities of its parent.
class V3LuxuryConnectionHero extends StatefulWidget {
  const V3LuxuryConnectionHero({
    super.key,
    required this.status,
    required this.locked,
    required this.onToggle,
    required this.nodeCode,
    required this.nodeName,
    required this.nodeLatencyMs,
    required this.readConnectedDuration,
    required this.upBps,
    required this.downBps,
    this.orbKey,
  });

  final ConnectionStatus status;
  final bool locked;
  final VoidCallback onToggle;
  final String nodeCode;
  final String nodeName;
  final int nodeLatencyMs;
  final Duration Function() readConnectedDuration;
  final ValueListenable<int> upBps;
  final ValueListenable<int> downBps;
  final Key? orbKey;

  @override
  State<V3LuxuryConnectionHero> createState() =>
      _V3LuxuryConnectionHeroState();
}

class _V3LuxuryConnectionHeroState extends State<V3LuxuryConnectionHero> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant V3LuxuryConnectionHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.status == ConnectionStatus.connected) {
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
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final connected = widget.status == ConnectionStatus.connected;
    final busy = widget.status == ConnectionStatus.connecting ||
        widget.status == ConnectionStatus.disconnecting;
    final failed = widget.status == ConnectionStatus.error;
    final statusColor = connected
        ? c.success
        : failed ? c.danger : busy ? c.gold : c.ink3;
    final statusLabel = switch (widget.status) {
      ConnectionStatus.connected =>
        v3Copy(context, zh: '已保护', en: 'Protected', tw: '已保護'),
      ConnectionStatus.connecting =>
        v3Copy(context, zh: '连接中', en: 'Connecting', tw: '連線中'),
      ConnectionStatus.disconnecting =>
        v3Copy(context, zh: '断开中', en: 'Disconnecting', tw: '中斷中'),
      ConnectionStatus.error =>
        v3Copy(context, zh: '未保护', en: 'Unprotected', tw: '未保護'),
      ConnectionStatus.disconnected =>
        v3Copy(context, zh: '未保护', en: 'Unprotected', tw: '未保護'),
    };
    final orbLabel = switch (widget.status) {
      ConnectionStatus.connected =>
        v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線'),
      ConnectionStatus.connecting =>
        v3Copy(context, zh: '连接中…', en: 'Connecting…', tw: '連線中…'),
      ConnectionStatus.disconnecting =>
        v3Copy(context, zh: '断开中…', en: 'Disconnecting…', tw: '中斷中…'),
      ConnectionStatus.error =>
        v3Copy(context, zh: '重新连接', en: 'Retry', tw: '重新連線'),
      ConnectionStatus.disconnected =>
        v3Copy(context, zh: '立即连接', en: 'Connect', tw: '立即連線'),
    };

    // The face changes MATERIAL, not merely a status caption:
    // outlined translucent gold = idle, solid gold/charcoal = busy/active,
    // outlined red translucent glass = failed.
    final solidFace = connected || busy;
    final face = solidFace ? c.orbFace : c.surfaceStrong;
    final edge = failed ? c.danger : c.gold;
    final faceInk = solidFace ? c.onGold : edge;

    return V3LuxuryGlassCard(
      hero: true,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 358,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerX = width / 2;
          const centerY = 134.0;
          final ringScale = math.min(1.0, (width - 16) / 340);
          final outer = 340 * ringScale;

          Widget ring(double diameter, Color color) {
            final size = diameter * ringScale;
            return Positioned(
              left: centerX - size / 2,
              top: centerY - size / 2,
              height: size,
              width: size,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1),
                  ),
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Concentric 340/264/196px tracks are absolutely positioned,
              // and scale together on narrow devices.
              ring(340, c.line),
              ring(264, c.lineStrong),
              ring(196, c.lineStrong),
              Positioned(
                left: centerX + outer * .24,
                top: centerY + outer * .14,
                child: _LuxuryOrbitDot(color: c.gold, size: 6),
              ),
              Positioned(
                left: centerX - outer * .32,
                top: centerY - outer * .22,
                child: _LuxuryOrbitDot(color: c.ink3, size: 5),
              ),
              Positioned(
                top: 15, left: 15,
                child: Container(
                  key: const Key('v3-luxury-protection-status'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceStrong,
                    borderRadius: BorderRadius.circular(V3LuxuryRadius.pill),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(statusLabel,
                      style: TextStyle(color: c.ink2,
                        fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
              // The 140px primary action is a single accessible control.
              Positioned(
                top: centerY - 70, left: centerX - 70,
                child: Semantics(
                  key: widget.orbKey,
                  button: true,
                  enabled: !widget.locked && !busy,
                  label: orbLabel,
                  onTap: widget.locked || busy ? null : widget.onToggle,
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('v3-luxury-orb-action'),
                        onTap: widget.locked || busy
                            ? null : widget.onToggle,
                        customBorder: const CircleBorder(),
                        child: AnimatedContainer(
                          key: const Key('v3-luxury-orb-face'),
                          duration: const Duration(milliseconds: 220),
                          height: 140, width: 140,
                          decoration: BoxDecoration(
                            color: face,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: edge, width: failed ? 1.6 : 1.1),
                            boxShadow: solidFace && dark
                                ? [BoxShadow(color: c.gold.withValues(alpha: .35),
                                    blurRadius: 30, spreadRadius: 3)]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (busy)
                                SizedBox(
                                  width: 31, height: 31,
                                  child: CircularProgressIndicator(
                                    key: const Key('v3-luxury-orb-loading'),
                                    strokeWidth: 2,
                                    color: faceInk),
                                )
                              else
                                Icon(Icons.power_settings_new_rounded,
                                  color: faceInk, size: 37),
                              const SizedBox(height: 9),
                              Text(orbLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: faceInk,
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 15, right: 15, top: 212,
                child: Column(children: [
                  if (failed)
                    Text(
                      v3Copy(context, zh: '连接失败',
                        en: 'Connection failed', tw: '連線失敗'),
                      key: const Key('v3-luxury-error-title'),
                      style: TextStyle(color: c.danger,
                        fontSize: 17, fontWeight: FontWeight.w600))
                  else
                    Text(
                      connected
                          ? _duration(widget.readConnectedDuration())
                          : busy ? '--:--:--' : '00:00:00',
                      key: const Key('v3-luxury-connection-duration'),
                      style: TextStyle(
                        color: connected ? c.ink : c.ink3,
                        fontSize: 28, fontWeight: FontWeight.w500,
                        letterSpacing: -.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (failed)
                    Text(
                      v3Copy(context,
                        zh: '连接未成功，请检查网络或切换节点',
                        en: 'Check your network or choose another node',
                        tw: '連線未成功，請檢查網路或切換節點'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.danger, fontSize: 10))
                  else if (busy)
                    Text(v3Copy(context,
                      zh: '正在建立或关闭安全通道…',
                      en: 'Updating secure connection…',
                      tw: '正在建立或關閉安全通道…'),
                      style: TextStyle(color: c.ink2, fontSize: 10))
                  else if (!connected)
                    Text(v3Copy(context, zh: '点击开始连接',
                      en: 'Tap to connect', tw: '點擊開始連線'),
                      style: TextStyle(color: c.ink3, fontSize: 10))
                  else
                    _LuxuryLiveSpeeds(
                      connected: connected,
                      upBps: widget.upBps,
                      downBps: widget.downBps,
                    ),
                ]),
              ),
              // Node chip is informational only; the existing node card
              // below the hero keeps the actual navigation action.
              Positioned(
                left: 15, right: 15, bottom: 12,
                child: Center(child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: c.surfaceStrong,
                    borderRadius: BorderRadius.circular(V3LuxuryRadius.pill),
                    border: Border.all(color: c.glassBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    V3NodeFlag(code: widget.nodeCode),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: math.max(
                        100.0, width - 155)),
                      child: Text(widget.nodeName.isEmpty
                          ? v3Copy(context, zh: '尚未选择节点',
                              en: 'No node selected', tw: '尚未選擇節點')
                          : widget.nodeName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.ink,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (widget.nodeLatencyMs > 0 &&
                        widget.nodeLatencyMs < 9999) ...[
                      const SizedBox(width: 7),
                      Text('${widget.nodeLatencyMs}ms',
                        style: TextStyle(color: c.success, fontSize: 10)),
                    ],
                  ]),
                )),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _LuxuryOrbitDot extends StatelessWidget {
  const _LuxuryOrbitDot({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _LuxuryLiveSpeeds extends StatelessWidget {
  const _LuxuryLiveSpeeds({
    required this.connected, required this.upBps, required this.downBps,
  });
  final bool connected;
  final ValueListenable<int> upBps;
  final ValueListenable<int> downBps;

  @override
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: upBps,
      builder: (context, up, _) => ValueListenableBuilder<int>(
        valueListenable: downBps,
        builder: (context, down, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('↑ ${_speed(connected ? up : 0)}',
              style: TextStyle(color: c.aqua, fontSize: 11)),
            const SizedBox(width: 14),
            Text('↓ ${_speed(connected ? down : 0)}',
              style: TextStyle(color: c.ink2, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// All session values are deliberately gated by current live connection
/// state. A disconnected/error/loading screen must never reuse stale byte
/// counters from the last successful session.
class V3LuxurySessionMetrics extends StatelessWidget {
  const V3LuxurySessionMetrics({
    super.key,
    required this.status,
    required this.downBps,
    required this.upBps,
    required this.sessionBytes,
  });

  final ConnectionStatus status;
  final ValueListenable<int> downBps;
  final ValueListenable<int> upBps;
  final ValueListenable<int> sessionBytes;

  @override
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    final live = status == ConnectionStatus.connected;
    return V3LuxuryGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: ValueListenableBuilder<int>(
        valueListenable: downBps,
        builder: (context, down, _) => ValueListenableBuilder<int>(
          valueListenable: upBps,
          builder: (context, up, _) => ValueListenableBuilder<int>(
            valueListenable: sessionBytes,
            builder: (context, session, _) => Row(children: [
              _SessionCell(label: v3Copy(context,
                zh: '下载', en: 'Download', tw: '下載'),
                value: _speed(live ? down : 0), color: c.ink),
              _SessionDivider(color: c.lineStrong),
              _SessionCell(label: v3Copy(context,
                zh: '上传', en: 'Upload', tw: '上傳'),
                value: _speed(live ? up : 0), color: c.ink),
              _SessionDivider(color: c.lineStrong),
              _SessionCell(label: v3Copy(context,
                zh: '本次流量', en: 'Session', tw: '本次流量'),
                value: _bytes(live ? session : 0), color: c.ink),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SessionDivider extends StatelessWidget {
  const _SessionDivider({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: color);
}

class _SessionCell extends StatelessWidget {
  const _SessionCell({
    required this.label, required this.value, required this.color,
  });
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final c = V3LuxuryTokens.of(context);
    return Expanded(child: Column(children: [
      Text(label, style: TextStyle(color: c.ink3, fontSize: 10)),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, maxLines: 1,
          style: TextStyle(color: color, fontSize: 13,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    ]));
  }
}

String _speed(int bps) {
  if (bps >= 1024 * 1024) {
    return '${(bps / 1024 / 1024).toStringAsFixed(1)} MB/s';
  }
  if (bps >= 1024) {
    return '${(bps / 1024).toStringAsFixed(0)} KB/s';
  }
  return '$bps B/s';
}

String _bytes(int value) {
  if (value >= 1024 * 1024 * 1024) {
    return '${(value / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
  if (value >= 1024 * 1024) {
    return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
  return '0 MB';
}

String _duration(Duration value) {
  final hours = value.inHours.toString().padLeft(2, '0');
  final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

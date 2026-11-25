import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../app/app_controller.dart';
import '../../app/core_controller.dart';
import '../../app/plan_presentation.dart';
import '../../shared/models/app_models.dart';
import '../theme/v3_palette.dart';
import '../theme/v3_motion.dart';
import '../ui/v3_components.dart';
import '../ui/v3_dashboard_alerts.dart';
import '../ui/v3_html_phone_notice.dart';
import '../ui/v3_latency_tier.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_toast.dart';
import '../ui/v3_node_tags.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_notice_bar.dart';
import '../ui/v3_notice_carousel.dart';
import '../ui/v3_plan_labels.dart';
import '../ui/v3_world_map.dart';

/// One connection page: the desktop rail must never add a second Home route.
class V3DashboardPage extends StatelessWidget {
  const V3DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    // Only a confirmed account without a plan sees the purchase guidance.
    final confirmedNoPlan =
        !controller.isInitialLoading && controller.hasConfirmedNoPlan;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: v3UsesMergedConnectionCard(defaultTargetPlatform)
          ? const EdgeInsets.fromLTRB(12, 12, 12, 110)
          : V3Layout.pageInsets,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: V3Entrance.wave([
          if (v3UsesMergedConnectionCard(defaultTargetPlatform)) ...[
            V3PrimaryPageHeader(
              title: v3Copy(context, zh: '连接',
                  en: 'Connect', tw: '連線'),
              subtitle: v3Copy(context, zh: '连接状态与路由模式',
                  en: 'Connection and routing',
                  tw: '連線狀態與路由模式'),
            ),
            const SizedBox(height: 14),
          ],
          // Phones: announcement images from the backend rotate in a card;
          // desktop keeps the slim ticker so the orb stays above the fold.
          if (v3UsesMergedConnectionCard(defaultTargetPlatform))
            controller.updateInfo != null
                ? V3NoticeCarousel(controller: controller)
                : V3HtmlPhoneNotice(controller: controller)
          else
            V3NoticeBar(controller: controller),
          V3DashboardAlerts(controller: controller),
          if (confirmedNoPlan)
            _NoPlanDashboardPanel(controller: controller)
          else if (v3UsesMergedConnectionCard(defaultTargetPlatform)) ...[
            // A clean mobile connection flow: map + animated connect orb,
            // routing capsule, real daily usage, and the node shortcut.
            // Desktop-only metrics and the subscription hero stay off this page.
            _MobileConnectSection(controller: controller),
          ] else ...[
            // Desktop composition (blueprint §2.2): the dot map is the page
            // stage, and one floating glass panel carries every live control
            // — node, modes, speed curve + metrics, plan summary.
            _DesktopWorkspace(controller: controller),
          ],
        ]),
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
            Icon(Icons.inventory_2_rounded, size: 34, color: p.inkMuted),
            const SizedBox(height: 12),
            Text(
              v3Copy(
                context,
                zh: '当前没有可用套餐',
                en: 'No active plan',
                tw: '目前沒有可用方案',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              v3Copy(
                context,
                zh: canBuy ? '选择套餐后即可开始连接。' : '请联系服务商开通套餐。',
                en: canBuy
                    ? 'Choose a plan to start connecting.'
                    : 'Contact your provider to activate a plan.',
                tw: canBuy ? '選擇方案後即可開始連線。' : '請聯絡服務商開通方案。',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 12),
            ),
            if (canBuy) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('v3-dashboard-no-plan-buy'),
                onPressed: () => controller.goToPage(AppPage.shop),
                style: FilledButton.styleFrom(
                  backgroundColor: p.lychee,
                  foregroundColor: p.onLychee,
                  minimumSize: const Size(156, 44),
                ),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: Text(
                  v3Copy(context, zh: '选择套餐', en: 'Choose a plan', tw: '選擇方案'),
                ),
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


/// Desktop composition (blueprint §2.2): the dot map owns the stage; one
/// floating glass panel carries every live control — node, modes, the live
/// speed curve with the four metrics, and the plan summary.
class _DesktopWorkspace extends StatelessWidget {
  const _DesktopWorkspace({required this.controller});
  final AppController controller;

  /// The stage holds the map, orb and timer; the panel matches its height.
  static const double _stageHeight = 536;
  static const double _panelWidth = 320;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final stage = V3WorkspaceCard(
      key: kConnectActionCardKey,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        child: _ConnectIntroContent(
          controller: controller,
          status: status,
        ),
      ),
    );
    final panel = _GlassPanel(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NodeSection(controller: controller),
                    const SizedBox(height: 16),
                    Divider(color: p.line, height: 1),
                    const SizedBox(height: 16),
                    _ModeRail(controller: controller, flat: true),
                    const SizedBox(height: 16),
                    Divider(color: p.line, height: 1),
                    const SizedBox(height: 16),
                    _SessionMetrics(
                      controller: controller,
                      flat: true,
                      showCurve: true,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: p.line, height: 1),
                    const SizedBox(height: 16),
                    _PlanSummary(controller: controller, flat: true),
                  ],
                ),
              ),
            );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Narrow windows stack: the stage keeps the hero, the panel drops
        // under it at full width. Desktop at 900×700 uses the side-by-side
        // composition.
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 320, child: stage),
              const SizedBox(height: 12),
              SizedBox(
                height: 520,
                child: panel,
              ),
            ],
          );
        }
        return SizedBox(
          height: _stageHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stage),
              const SizedBox(width: 12),
              SizedBox(width: _panelWidth, child: panel),
            ],
          ),
        );
      },
    );
  }
}

/// The light glass surface (blueprint §1.4): a static blur behind a
/// translucent fill and a 1px highlight stroke. Desktop-only.
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final radius = BorderRadius.circular(V3Radius.panel);
    return Container(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: p.shadows),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.glass,
              borderRadius: radius,
              border: Border.all(color: p.glassBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The panel's node section: identity, latency, tags and the switch entry.
class _NodeSection extends StatelessWidget {
  const _NodeSection({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final node = controller.currentNode;
    final displayName = controller.autoSelected
        ? node.name.isEmpty
              ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
              : node.name
        : node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点', en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return Column(
      key: kCurrentNodeCardKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              v3Copy(context, zh: '当前节点', en: 'Current node', tw: '目前節點'),
              style: TextStyle(
                color: p.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            V3LatencyBadge(
              region: node.region,
              latency: node.latency,
              signal: true,
              statusSized: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(V3Radius.field),
              ),
              child: V3NodeFlag(code: node.code, large: true),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                      if (controller.autoSelected && node.name.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.lycheeSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            v3Copy(context, zh: '自动', en: 'Auto', tw: '自動'),
                            style: TextStyle(
                              color: p.lycheeInk,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    node.englishName.isNotEmpty ? node.englishName : node.code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (node.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          V3NodeTags(tags: node.tags, maxVisible: 2),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: () => V3NodePicker.show(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V3Radius.field),
              ),
            ),
            icon: Icon(Icons.swap_horiz_rounded, size: 18, color: p.lychee),
            label: Text(
              v3Copy(context, zh: '切换节点', en: 'Change node', tw: '切換節點'),
            ),
          ),
        ),
      ],
    );
  }
}

/// The live throughput curve (blueprint §4): a 90-sample ring buffer fed by
/// the controller's speed notifiers — event-driven, no timers. Download
/// draws green with a soft area fill, upload draws aqua; the y-scale is
/// fixed at 14 MB/s so idle flatlines read as idle.
class _SpeedSparkline extends StatefulWidget {
  const _SpeedSparkline({required this.controller, required this.height});
  final AppController controller;
  final double height;

  @override
  State<_SpeedSparkline> createState() => _SpeedSparklineState();
}

class _SpeedSparklineState extends State<_SpeedSparkline> {
  static const int _kSamples = 90;
  final List<double> _down = <double>[];
  final List<double> _up = <double>[];
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    widget.controller.downBpsNotifier.addListener(_sample);
    widget.controller.upBpsNotifier.addListener(_sample);
  }

  void _detach() {
    widget.controller.downBpsNotifier.removeListener(_sample);
    widget.controller.upBpsNotifier.removeListener(_sample);
  }

  @override
  void didUpdateWidget(covariant _SpeedSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.downBpsNotifier.removeListener(_sample);
      oldWidget.controller.upBpsNotifier.removeListener(_sample);
      _attach();
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _sample() {
    if (!mounted) return;
    _push();
    setState(() {});
  }

  void _push() {
    final down = widget.controller.downBpsNotifier.value / (1024 * 1024);
    final up = widget.controller.upBpsNotifier.value / (1024 * 1024);
    if (!_filled) {
      _down.addAll(List<double>.filled(_kSamples, down));
      _up.addAll(List<double>.filled(_kSamples, up));
      _filled = true;
      return;
    }
    _down.add(down);
    _up.add(up);
    if (_down.length > _kSamples) _down.removeAt(0);
    if (_up.length > _kSamples) _up.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    if (!_filled) _push();
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparkPainter(
            down: List<double>.of(_down),
            up: List<double>.of(_up),
            palette: p,
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.down, required this.up, required this.palette});
  final List<double> down;
  final List<double> up;
  final V3Palette palette;

  static const double _maxMbps = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width;
    final h = size.height;
    double yOf(double mbps) =>
        h - 1 - (mbps.clamp(0, _maxMbps) / _maxMbps) * (h - 4);
    double xOf(int i) => down.length < 2 ? 0 : w * i / (down.length - 1);

    canvas.drawLine(
      Offset(0, h - 0.5),
      Offset(w, h - 0.5),
      Paint()
        ..color = palette.line
        ..strokeWidth = 1,
    );

    if (down.length > 1) {
      // Download: soft area under the line, then the line itself.
      final area = Path()..moveTo(0, h);
      for (var i = 0; i < down.length; i++) {
        area.lineTo(xOf(i), yOf(down[i]));
      }
      area
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.success.withValues(alpha: 0.18),
              palette.success.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      final downLine = Path()..moveTo(xOf(0), yOf(down[0]));
      for (var i = 1; i < down.length; i++) {
        downLine.lineTo(xOf(i), yOf(down[i]));
      }
      canvas.drawPath(
        downLine,
        Paint()
          ..color = palette.success
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (up.length > 1) {
      final upLine = Path()..moveTo(xOf(0), yOf(up[0]));
      for (var i = 1; i < up.length; i++) {
        upLine.lineTo(xOf(i), yOf(up[i]));
      }
      canvas.drawPath(
        upLine,
        Paint()
          ..color = palette.aqua
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.down.length != down.length ||
      old.up.length != up.length ||
      old.down.lastOrNull != down.lastOrNull ||
      old.up.lastOrNull != up.lastOrNull ||
      old.palette != palette;
}

class _ConnectIntroContent extends StatefulWidget {
  const _ConnectIntroContent({required this.controller, required this.status});
  final AppController controller;
  final ConnectionStatus status;

  @override
  State<_ConnectIntroContent> createState() => _ConnectIntroContentState();
}

class _ConnectIntroContentState extends State<_ConnectIntroContent> {
  /// A local core can flip busy→terminal in tens of milliseconds, which
  /// collapses the connect sequence into a snap. The amber state is the
  /// presentation: hold it on screen for at least this long so the eye reads
  /// tap → spinner → lime ripple as one motion. A handshake slower than the
  /// floor simply displays for its real duration.
  static const Duration _minBusyDisplay = Duration(milliseconds: 700);

  late ConnectionStatus _shown = widget.status;
  DateTime? _busySince;
  Timer? _release;

  static bool _isBusy(ConnectionStatus state) =>
      state == ConnectionStatus.connecting ||
      state == ConnectionStatus.disconnecting;

  @override
  void didUpdateWidget(covariant _ConnectIntroContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.status;
    if (target == _shown) return;
    if (_isBusy(_shown) && !_isBusy(target)) {
      // Busy just ended: keep the amber frame until the floor elapses.
      final held = _busySince == null
          ? _minBusyDisplay
          : DateTime.now().difference(_busySince!);
      if (held < _minBusyDisplay) {
        final snapshot = target;
        _release?.cancel();
        _release = Timer(_minBusyDisplay - held, () {
          if (!mounted) return;
          setState(() {
            _shown = snapshot;
            _busySince = null;
            _release = null;
          });
        });
        return;
      }
      setState(() {
        _shown = target;
        _busySince = null;
      });
      return;
    }
    // Entering busy (or any idle hop, e.g. →error): show it immediately.
    if (_isBusy(target)) _busySince ??= DateTime.now();
    _release?.cancel();
    _release = null;
    setState(() => _shown = target);
  }

  @override
  void dispose() {
    _release?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = _shown;
    final connected = status == ConnectionStatus.connected;
    final connecting = _isBusy(status);
    // The corner badge speaks protection, not connection: red only while a
    // real fault exposes the tunnel, quiet gray for plain idle, lime once the
    // tunnel is up. The orb button below carries the live state.
    final protectionColor = _protectionColor(p, status);
    // The caption below the orb cross-fades on state changes; compute it once
    // so the AnimatedSwitcher key and the Text share one source.
    final caption = connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : connecting
        ? v3Copy(context, zh: '处理中', en: 'Processing', tw: '處理中')
        : v3Copy(context, zh: '点击开始连接', en: 'Tap to connect', tw: '點擊開始連線');
    return Stack(
      children: [
        // The workspace card's background: the low-contrast dot-matrix world
        // map, the same painter the phone stage unfurls at page level. The
        // coastlines' card carries the ambience; the card structure above it
        // is untouched.
        const Positioned.fill(child: V3WorldMap()),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(V3Layout.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Node-card style: one badge in the top-right corner. The
                // orb button already shows the live state, so the label
                // speaks protection instead of echoing "connected" again.
                Row(
                  children: [
                    Expanded(
                      child: Text(
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
                    ),
                    AnimatedSwitcher(
                      duration: V3Motion.fast,
                      switchInCurve: V3Motion.ease,
                      switchOutCurve: V3Motion.ease.flipped,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: V3StatusBadge(
                        key: ValueKey(status),
                        label: _protectionLabel(context, status),
                        color: protectionColor,
                        // A shield instead of a dot: filled while protected,
                        // hollow the moment protection drops.
                        icon: status == ConnectionStatus.connected
                            ? Icons.shield_rounded
                            : Icons.shield_outlined,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ConnectionOrb(
                          controller: widget.controller,
                          status: status,
                        ),
                        const SizedBox(height: 9),
                        _ConnectionDuration(controller: widget.controller),
                        const SizedBox(height: 5),
                        AnimatedSwitcher(
                          duration: V3Motion.fast,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.35),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Text(
                            caption,
                            key: ValueKey(caption),
                            // The action hint is a footnote beneath the
                            // display-size session timer above it.
                            style: TextStyle(
                              color: p.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
      ],
    );
  }
}

/// Mobile: map and connection orb, routing mode, compact daily usage,
/// then the current-node shortcut. The desktop workspace is unchanged.
class _MobileConnectSection extends StatefulWidget {
  const _MobileConnectSection({required this.controller});
  final AppController controller;

  @override
  State<_MobileConnectSection> createState() => _MobileConnectSectionState();
}

class _MobileConnectSectionState extends State<_MobileConnectSection>
    with _ModeSwitching {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        _MobileConnectStage(controller: controller),
        const SizedBox(height: V3Layout.cardGap),
        // Native routing mode values stay bound to the existing controller.
        _ModeSegment<ProxyMode>(
          values: ProxyMode.values,
          label: _modeTitle,
          selected: controller.proxyMode,
          busy: _busy,
          onSelect: (mode) => _runModeSwitch(() => _setProxyMode(mode)),
          trackKey: 'v3-route-mode-track',
        ),
        const SizedBox(height: V3Layout.cardGap),
        _MobileTodayUsageCard(controller: controller),
        const SizedBox(height: V3Layout.cardGap),
        _MobileNodeCard(controller: controller),
      ],
    );
  }
}

/// Two compact, real-data metrics in the same neutral visual language as
/// Wallet and the account-service cards. Never infer today's traffic from
/// the subscription's total used quota.
class _MobileTodayUsageCard extends StatelessWidget {
  const _MobileTodayUsageCard({required this.controller});

  final AppController controller;

  static String _formatGb(double value) => value < 1
      ? '${(value * 1024).toStringAsFixed(0)} MB'
      : '${value.toStringAsFixed(2)} GB';

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final hasDailyData = controller.trafficUsage.isNotEmpty;
    final today = hasDailyData
        ? _formatGb(controller.todayTrafficGb)
        : '—';
    final remaining = controller.isInitialLoading &&
            controller.traffic.totalGb <= 0
        ? '—'
        : '${controller.traffic.remainGb.toStringAsFixed(1)} GB';
    return Container(
      key: const ValueKey('v3-mobile-daily-usage'),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.card),
        border: Border.all(color: p.line.withValues(alpha: .72)),
      ),
      child: Row(children: [
        Expanded(child: _MobileUsageStat(
          label: v3Copy(context, zh: '今日已用',
            en: 'Used today', tw: '今日已用'),
          value: today,
        )),
        Container(width: 1, height: 38,
          color: p.line.withValues(alpha: .72)),
        const SizedBox(width: 18),
        Expanded(child: _MobileUsageStat(
          label: v3Copy(context, zh: '剩余流量',
            en: 'Remaining', tw: '剩餘流量'),
          value: remaining,
        )),
      ]),
    );
  }
}

class _MobileUsageStat extends StatelessWidget {
  const _MobileUsageStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: p.inkMuted, fontSize: 11)),
      const SizedBox(height: 5),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value, maxLines: 1,
          style: TextStyle(color: p.ink, fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ),
    ]);
  }
}

/// The phone connection surface: framed dot map with an approximate
/// country marker for the active node, then a wide capsule action and timer.
/// Desktop continues to use the existing animated connection orb.
class _MobileConnectStage extends StatelessWidget {
  const _MobileConnectStage({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final status = controller.connectionStatus;
    final connected = status == ConnectionStatus.connected;
    final node = controller.currentNode;
    final nodeName = node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点',
            en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return Container(
      key: kConnectActionCardKey,
      height: 375,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Radius.card),
        border: Border.all(color: p.line.withValues(alpha: .72)),
      ),
      child: Column(children: [
        Expanded(child: Stack(children: [
          const Positioned.fill(child: V3WorldMap()),
          // Backend supplies a country code, not precise server coordinates.
          Positioned.fill(child: V3WorldMapNodePin(
            countryCode: node.code, connected: connected)),
          Positioned(left: 15, top: 15,
            child: V3StatusBadge(
              label: _protectionLabel(context, status),
              color: _protectionColor(p, status),
              icon: connected ? Icons.shield_rounded : Icons.shield_outlined,
            )),
          Positioned(left: 15, right: 15, bottom: 12,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: .94),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: p.line.withValues(alpha: .72)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  V3NodeFlag(code: node.code),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 205),
                    child: Text(nodeName,
                      overflow: TextOverflow.ellipsis, maxLines: 1,
                      style: TextStyle(color: p.ink, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ])),
        ])),
        Divider(height: 1, thickness: 1,
          color: p.line.withValues(alpha: .72)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text(v3Copy(context, zh: '连接时长',
                    en: 'Duration', tw: '連線時長'),
                  style: TextStyle(color: p.inkMuted, fontSize: 11)),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(
                  height: 28,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _ConnectionDuration(controller: controller),
                  ),
                )),
              ]),
              if (connected) ...[
                const SizedBox(height: 7),
                // The full up/down readout needs up to 319dp; fit it inside
                // the available 302dp on compact 360dp phones without
                // dropping transfer values or overflowing the card.
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _SpeedSuffix(
                      controller: controller, visible: connected),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Full-width CTA: neither the timer nor transfer-rate labels
              // share its row on 320–390dp devices.
              _MobileConnectCapsule(controller: controller, status: status),
            ],
          ),
        ),
      ]),
    );
  }
}

/// Mobile-only primary connection control. Reuse the actual controller action,
/// busy/locked state and status colours rather than a decorative mock button.
class _MobileConnectCapsule extends StatelessWidget {
  const _MobileConnectCapsule({
    required this.controller,
    required this.status,
  });

  final AppController controller;
  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final busy = status == ConnectionStatus.connecting ||
        status == ConnectionStatus.disconnecting;
    final connected = status == ConnectionStatus.connected;
    final locked = controller.connectionActionLocked;
    final color = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.lychee,
    };
    final label = busy
        ? v3Copy(context, zh: '连接处理中',
            en: 'Processing', tw: '連線處理中')
        : connected
            ? v3Copy(context, zh: '断开连接',
                en: 'Disconnect', tw: '中斷連線')
            : v3Copy(context, zh: '立即连接',
                en: 'Connect', tw: '立即連線');

    Future<void> runToggle() async {
      final error = await controller.toggleConnection();
      if (error == null &&
          context.mounted &&
          controller.connectionStatus == ConnectionStatus.connected) {
        V3Toast.show(context, v3Copy(context,
          zh: '连接成功', en: 'Connected', tw: '連線成功'),
          type: V3ToastType.success);
      }
    }

    return Semantics(
      key: kConnectOrbKey,
      container: true,
      button: true,
      enabled: !locked,
      label: label,
      onTap: locked ? null : runToggle,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: V3Motion.fast,
          width: double.infinity, height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('v3-mobile-connect-pill'),
              onTap: locked ? null : runToggle,
              borderRadius: BorderRadius.circular(99),
              child: Center(child: AnimatedSwitcher(
                duration: V3Motion.fast,
                child: busy
                    ? SizedBox(
                        key: const ValueKey('v3-mobile-connect-loading'),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: p.onLychee))
                    : Row(
                        key: ValueKey('v3-mobile-connect-${connected ? 'on' : 'off'}'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(connected ? Icons.stop_rounded
                              : Icons.power_settings_new_rounded,
                            size: 18, color: connected ? p.night : p.onLychee),
                          const SizedBox(width: 7),
                          Text(label, style: TextStyle(
                            color: connected ? p.night : p.onLychee,
                            fontSize: 13, fontWeight: FontWeight.w800)),
                        ]),
              )),
            ),
          ),
        ),
      ),
    );
  }
}

/// The node row as its own r22 card: the whole row opens the node picker, and
/// the data (flag, name, auto pill, latency, tags) matches the desktop route
/// card's identity block.
class _MobileNodeCard extends StatelessWidget {
  const _MobileNodeCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final node = controller.currentNode;
    final displayName = controller.autoSelected
        ? node.name.isEmpty
              ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
              : node.name
        : node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点', en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        border: Border.all(color: p.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        // V3Pressable keeps the press ink above the card's opaque fill - a
        // bare InkWell paints it on the root Material below.
        child: V3Pressable(
          key: kCurrentNodeCardKey,
          onTap: () => controller.goToPage(AppPage.nodes),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                                fontWeight: FontWeight.w600,
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
                                borderRadius: BorderRadius.circular(
                                  99,
                                ), // pill
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      V3LatencyBadge(
                        region: node.region,
                        latency: node.latency,
                      ),
                      if (node.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        V3NodeTags(tags: node.tags, maxVisible: 2),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: p.inkMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The phone stage's speed suffix under the timer: `↑ up · ↓ down` in the
/// aqua/green pair, connected only. Event-driven - the traffic values arrive
/// through ValueNotifiers, so this rebuilds only on a real value or
/// visibility change and carries no timer or ticker of its own, which also
/// makes it TickerMode-safe by construction.
class _SpeedSuffix extends StatelessWidget {
  const _SpeedSuffix({required this.controller, required this.visible});
  final AppController controller;
  final bool visible;

  /// The suffix's shared type: 12px bold tabular figures — the mockup's
  /// `.js-speed-suffix` set — with the per-segment ink passed in.
  static TextStyle suffixInk(Color color) => TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final p = V3Palette.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: controller.upBpsNotifier,
      builder: (context, up, _) => ValueListenableBuilder<int>(
        valueListenable: controller.downBpsNotifier,
        builder: (context, down, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '↑ ${_speed(up)}',
              style: suffixInk(p.aquaInk),
            ),
            Text(
              '  ·  ',
              style: suffixInk(p.inkMuted),
            ),
            Text(
              '↓ ${_speed(down)}',
              style: suffixInk(p.successInk),
            ),
          ],
        ),
      ),
    );
  }
}

/// The connect action: fill, icon and halo transition with the connection
/// state machine instead of snapping. One-shots (success ripple, error shake)
/// fire only on live transitions — never on mount, so an error-banner mount
/// stays still.
class _ConnectionOrb extends StatefulWidget {
  const _ConnectionOrb({
    required this.controller,
    required this.status,
    this.size = 86,
  });
  final AppController controller;
  final ConnectionStatus status;

  /// The orb's diameter. The phone stage enlarges the tap target to 96 (the
  /// accepted mockup's `.orb` bump); the desktop card keeps 86.
  final double size;

  @override
  State<_ConnectionOrb> createState() => _ConnectionOrbState();
}

class _ConnectionOrbState extends State<_ConnectionOrb>
    with TickerProviderStateMixin {
  static bool _isBusy(ConnectionStatus state) =>
      state == ConnectionStatus.connecting ||
      state == ConnectionStatus.disconnecting;

  // Breathe loop: only ticks while a connect/disconnect is in flight, so the
  // resting orb carries zero active tickers.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    // Bespoke 1400ms: a resting ambience breath, slower than any V3Motion
    // token so it reads as the orb being alive, never as a transition.
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _breathe = CurvedAnimation(
    parent: _pulse,
    curve: Curves.easeInOut,
  );
  // One-shot success ripple (busy → connected).
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    // Bespoke 450ms: a one-shot celebration bloom between fast and slow —
    // long enough to read, short enough not to lag the state swap.
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _rippleEase = CurvedAnimation(
    parent: _ripple,
    curve: Curves.easeOutCubic,
  );
  // One-shot error shake.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: V3Motion.medium,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mounted mid-connect (silent start): join the breathe loop, but never
    // fire one-shots on mount. Reduced motion keeps the orb static — it still
    // swaps spinner/icon and color, just without the pulsing halo.
    if (!v3ReducedMotion(context) &&
        _isBusy(widget.status) &&
        !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _ConnectionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every AppScope notifyListeners rebuilds this subtree; only a real
    // status transition may touch the controllers.
    if (oldWidget.status == widget.status) return;
    final wasBusy = _isBusy(oldWidget.status);
    final isBusy = _isBusy(widget.status);
    final reduced = v3ReducedMotion(context);
    if (isBusy && !wasBusy) {
      if (!reduced) _pulse.repeat(reverse: true);
    } else if (!isBusy && wasBusy) {
      _pulse
        ..stop()
        ..value = 0;
    }
    if (reduced) return;
    if (widget.status == ConnectionStatus.connected) _ripple.forward(from: 0);
    if (widget.status == ConnectionStatus.error) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ripple.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = widget.controller;
    final status = widget.status;
    final size = widget.size;
    final locked = controller.connectionActionLocked;
    final busy = _isBusy(status);
    final connected = status == ConnectionStatus.connected;
    // The new orb semantics: connected is success green (the old citrus fill
    // predates the palette's green-for-confirmed rule), busy stays amber,
    // error red, disconnected the lychee coral.
    final orbColor = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.lychee,
    };
    final label = busy
        ? v3Copy(context, zh: '正在切换连接', en: 'Changing connection', tw: '正在切換連線')
        : connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : v3Copy(context, zh: '连接', en: 'Connect', tw: '連線');
    // The orb is the page's primary control: assistive tech must fire exactly
    // what a tap fires. ExcludeSemantics below prunes the InkWell's own
    // semantics, so the tap action has to live on this outer node.
    Future<void> runToggle() async {
      // Failure remains a persistent alert with a retry action.
      final error = await controller.toggleConnection();
      if (error == null &&
          context.mounted &&
          controller.connectionStatus == ConnectionStatus.connected) {
        V3Toast.show(
          context,
          v3Copy(
            context,
            zh: '连接成功',
            en: 'Connected',
            tw: '連線成功',
          ),
          type: V3ToastType.success,
        );
      }
    }

    return Semantics(
      key: kConnectOrbKey,
      container: true,
      button: true,
      enabled: !locked,
      label: label,
      onTap: locked ? null : runToggle,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // FX layer rides outside the tap target's bounds without taking
              // layout space: halo while busy, success ripple on connect. The
              // box stays 42dp larger than the orb on either side of any size.
              Positioned(
                left: -21,
                top: -21,
                width: size + 42,
                height: size + 42,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_pulse, _ripple]),
                      builder: (context, _) => CustomPaint(
                        painter: _OrbFxPainter(
                          breathe: _breathe.value,
                          haloActive: _pulse.isAnimating,
                          ripple: _rippleEase.value,
                          rippleActive:
                              _ripple.isAnimating || _ripple.value < 1.0,
                          haloColor: p.warning,
                          rippleColor: p.success,
                          orbRadius: size / 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  return Transform.translate(
                    offset: Offset(math.sin(t * math.pi * 3) * 4 * (1 - t), 0),
                    child: child,
                  );
                },
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: orbColor),
                  duration: V3Motion.fast,
                  curve: Curves.easeOut,
                  builder: (context, color, _) => SizedBox(
                    width: size,
                    height: size,
                    child: Material(
                      color: color!,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: locked ? null : runToggle,
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: V3Motion.fast,
                            switchInCurve: V3Motion.ease,
                            switchOutCurve: V3Motion.ease.flipped,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween(
                                      begin: 0.85,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: busy
                                ? SizedBox(
                                    key: const ValueKey('orb-spinner'),
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
                                    key: ValueKey(
                                      connected ? 'orb-stop' : 'orb-power',
                                    ),
                                    color: connected ? p.night : p.onLychee,
                                    size: 30,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Halo + ripple FX for the connect orb. Colors are resolved in build and
/// passed in, so dark mode is just another fill tween. `breathe`/`ripple`
/// are raw controller values; the painter stays silent when both are idle.
class _OrbFxPainter extends CustomPainter {
  const _OrbFxPainter({
    required this.breathe,
    required this.haloActive,
    required this.ripple,
    required this.rippleActive,
    required this.haloColor,
    required this.rippleColor,
    required this.orbRadius,
  });
  final double breathe;
  final bool haloActive;
  final double ripple;
  final bool rippleActive;
  final Color haloColor;
  final Color rippleColor;

  /// The orb's radius. The halo rides 2dp outside the rim and the ripple
  /// starts on the rim, so both scale with the phone stage's enlarged 96 orb.
  final double orbRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (haloActive) {
      // Radius grows while the ring fades: a slow exhale, not a bounce.
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = haloColor.withValues(alpha: 0.10 + 0.28 * (1 - breathe));
      canvas.drawCircle(center, orbRadius + 2 + 8 * breathe, halo);
    }
    if (rippleActive && ripple > 0.0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - ripple) + 0.5
        ..color = rippleColor.withValues(alpha: 0.5 * (1 - ripple));
      canvas.drawCircle(center, orbRadius + 18 * ripple, ring);
    }
  }

  @override
  bool shouldRepaint(_OrbFxPainter oldDelegate) =>
      oldDelegate.breathe != breathe ||
      oldDelegate.ripple != ripple ||
      oldDelegate.haloActive != haloActive ||
      oldDelegate.rippleActive != rippleActive ||
      oldDelegate.haloColor != haloColor ||
      oldDelegate.rippleColor != rippleColor ||
      oldDelegate.orbRadius != orbRadius;
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
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    // Display-level session timer: the single live number on the dashboard
    // gets the largest type in the workspace (M3 display role / HIG large
    // title). Tabular figures keep per-second digit swaps from shifting
    // glyphs; muted gray while idle reads as "not started".
    final connected =
        widget.controller.connectionStatus == ConnectionStatus.connected;
    return Text(
      _duration(widget.controller.connectedDuration),
      key: const Key('v3-connection-duration'),
      style: TextStyle(
        color: connected ? p.ink : p.inkMuted,
        fontSize: 28,
        height: 1.0,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Hide unsupported system-proxy status from Android and Linux Home.
bool v3ShowsNetworkMode(TargetPlatform platform, NetworkMode mode) =>
    mode == NetworkMode.tun ||
    platform == TargetPlatform.windows ||
    platform == TargetPlatform.macOS;

/// Phones merge connection, node and routing into one card; desktop keeps
/// the three-surface workspace.
bool v3UsesMergedConnectionCard(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;

class _ModeRail extends StatefulWidget {
  const _ModeRail({required this.controller, this.flat = false});
  final AppController controller;

  /// When true the rail renders bare (the glass panel supplies the surface).
  final bool flat;

  @override
  State<_ModeRail> createState() => _ModeRailState();
}

/// Both mode switchers reload the core config on switch; a second tap while
/// the first is still applying would race it. The busy lock and the two
/// switch actions live here so the desktop rail and the phone's merged card
/// share one contract.
mixin _ModeSwitching<T extends StatefulWidget> on State<T> {
  bool _busy = false;

  Future<void> _runModeSwitch(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  AppController get _modeController => (widget as dynamic).controller;

  Future<void> _setNetworkMode(NetworkMode mode) async {
    final controller = _modeController;
    final error = await controller.setNetworkMode(mode);
    if (!mounted) return;
    if (error != null) {
      V3Toast.show(context, error, type: V3ToastType.error);
      return;
    }
    final label = _networkModeLabel(context, mode);
    final applied = controller.coreProcessRunning
        ? v3Copy(
            context,
            zh: '已切换到$label，重连后生效',
            en: 'Switched mode; reconnect to apply it',
            tw: '已切換至$label，重新連線後生效',
          )
        : v3Copy(
            context,
            zh: '连接模式已切换，将在下次连接时生效',
            en: 'Mode switched. It applies on your next connection.',
            tw: '連線模式已切換，將於下次連線時生效',
          );
    V3Toast.show(context, applied, type: V3ToastType.success);
  }

  Future<void> _setProxyMode(ProxyMode mode) async {
    final error = await _modeController.setProxyMode(mode);
    if (!mounted) return;
    if (error != null) {
      V3Toast.show(context, error, type: V3ToastType.error);
      return;
    }
    V3Toast.show(
      context,
      v3Copy(
        context,
        zh: '已切换到${_modeTitle(context, mode)}',
        en: 'Switched to ${_modeTitle(context, mode)}',
        tw: '已切換至${_modeTitle(context, mode)}',
      ),
      type: V3ToastType.success,
    );
  }
}

class _ModeRailState extends State<_ModeRail> with _ModeSwitching {
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = widget.controller;
    final networkModes = NetworkMode.values
        .where((mode) => v3ShowsNetworkMode(defaultTargetPlatform, mode))
        .toList();
    // Android's VPN stack is always tunnelled and Linux has no system-proxy
    // setter: a selector with a single option would read as a broken choice,
    // so the whole network-mode group disappears there and only routing shows.
    final Widget? network = networkModes.length > 1
        ? Column(
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
                values: networkModes,
                label: _networkModeLabel,
                selected: controller.networkMode,
                busy: _busy,
                onSelect: (mode) => _runModeSwitch(() => _setNetworkMode(mode)),
                trackKey: 'v3-network-mode-track',
                optionKey: (mode) => 'v3-network-mode-${mode.storageKey}',
              ),
            ],
          )
        : null;
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
          onSelect: (mode) => _runModeSwitch(() => _setProxyMode(mode)),
          trackKey: 'v3-route-mode-track',
        ),
      ],
    );
    final content = LayoutBuilder(
        builder: (context, constraints) {
          if (network == null) return routing;
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
      );
    return widget.flat
        ? content
        : _DashboardCard(
            padding: const EdgeInsets.all(V3Layout.cardPadding),
            child: content,
          );
  }
}

/// A continuous segmented capsule: one raised track holding every option,
/// the current selection a soft lychee pill that slides between options —
/// the same pink selection language as the node rows and chips. Both
/// dashboard mode groups render through this widget so the 2-option and
/// 3-option groups read as one control family.
class _ModeSegment<T> extends StatelessWidget {
  const _ModeSegment({
    required this.values,
    required this.label,
    required this.selected,
    required this.busy,
    required this.onSelect,
    this.trackKey,
    this.optionKey,
  });
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
      child: Stack(
        children: [
          // The selection is a soft pill that slides between options — the
          // same lycheeSoft fill + lychee ring the node rows and chips select
          // with, so every V3 selection speaks one language. Aligning a 1/n
          // thumb on the [-1..1] axis gives iOS-style travel with no pixel
          // math, and the pill starts at the current selection so mounts
          // never animate.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedAlign(
                duration: V3Motion.fast,
                curve: V3Motion.ease,
                alignment: Alignment(
                  values.length < 2
                      ? 0
                      : -1 + 2 * values.indexOf(selected) / (values.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / values.length,
                  // DecoratedBox alone has no child and would collapse to
                  // zero under the loose align constraints — expand first so
                  // the pill actually fills its fraction of the track.
                  child: SizedBox.expand(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.lycheeSoft,
                        border: Border.all(color: p.lychee),
                        borderRadius: BorderRadius.circular(V3Radius.control),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final value in values)
                Expanded(
                  // Assistive tech: each option is its own button node with a
                  // selected flag inside a mutually exclusive group - the
                  // same contract SegmentedButton/NavigationDestination
                  // publish. V3Pressable rides above the thumb so the press
                  // ink lands on the option surface instead of on a Material
                  // beneath the card fill. The padding lives inside it so
                  // the ink still covers the full option rect.
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: value == selected,
                    inMutuallyExclusiveGroup: true,
                    onTap: busy || value == selected
                        ? null
                        : () => onSelect(value),
                    child: V3Pressable(
                      key: optionKey == null
                          ? null
                          : ValueKey<String>(optionKey!(value)),
                      onTap: busy || value == selected
                          ? null
                          : () => onSelect(value),
                      borderRadius: BorderRadius.circular(V3Radius.control),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: SizedBox(
                          width: double.infinity,
                          // The ink swap animates with the travelling pill; a
                          // bare TextStyle color would snap while the pill glides.
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(
                              end: value == selected ? p.lycheeInk : p.inkMuted,
                            ),
                            duration: V3Motion.fast,
                            curve: V3Motion.ease,
                            builder: (context, color, _) => Text(
                              label(context, value),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: selected == value
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The session card: four gauges in one row on desktop, a 2x2 grid on
/// phones. The reachability strip is appended on desktop only — a phone's
/// slots are far too narrow for four sites.
class _SessionMetrics extends StatelessWidget {
  const _SessionMetrics({
    required this.controller,
    this.flat = false,
    this.showCurve = false,
  });
  final AppController controller;

  /// Bare mode for the glass panel; [showCurve] adds the live sparkline.
  final bool flat;
  final bool showCurve;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCurve) ...[
            _SpeedSparkline(controller: controller, height: 64),
            const SizedBox(height: 14),
          ],
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
              // One shared cell inset keeps the columns on the same grid:
              // every label starts at the same offset from its divider.
              Widget cell(Widget metric) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: metric,
                ),
              );
              Widget divider() =>
                  Container(width: 1, height: 38, color: p.line);
              final gauge = compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [cell(session), cell(connections)]),
                        const SizedBox(height: 12),
                        Row(children: [cell(download), cell(upload)]),
                      ],
                    )
                  : Row(
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
              // The gauges are the card's whole content: the four-site
              // reachability strip is gone — it read a server-side story the
              // app can't act on, and the gauges already carry the live truth.
              return gauge;
            },
          ),
        ],
      );
    return flat
        ? content
        : _DashboardCard(
            padding: const EdgeInsets.all(V3Layout.cardPadding),
            child: content,
          );
  }
}

/// One gauge cell: an icon+label line over a tabular-figure value.
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
                  fontSize: 11,
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
          // Headline-level numerals with tabular figures: live gauges read
          // as data, and B/s updates never jiggle the glyph columns.
          style: TextStyle(
            color: p.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}


class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.controller, this.flat = false});
  final AppController controller;

  /// When true the summary renders bare (the glass panel supplies the
  /// surface); the desktop workspace uses this form.
  final bool flat;

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
            : v3Copy(context, zh: '今日到期', en: 'Expires today', tw: '今日到期');
        expiryUrgent = remaining.inDays < 3;
      }
    }
    final content = Column(
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
          const SizedBox(height: 10),
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
                child: Icon(Icons.diamond_rounded, color: p.citrusInk, size: 21),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      // An active plan needs no status word - the green
                      // countdown already says it. Abnormal states earn the
                      // suffix, except expiry: the expiry label already opens
                      // with that word. Kinds + localized labels, never the
                      // legacy Chinese display strings (round-3 audit N14).
                      plan.statusKind == PlanStatus.normal ||
                              plan.statusKind == PlanStatus.expired
                          ? v3PlanExpiryLabel(context, plan)
                          : '${v3PlanExpiryLabel(context, plan)} · ${v3PlanStatusLabel(context, plan.statusKind)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: plan.usable ? p.inkMuted : p.dangerInk,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(V3Radius.card),
              // The bar sweeps from empty on load and glides between values
              // on refresh instead of jumping to the new fill.
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: v3ReducedMotion(context)
                    ? Duration.zero
                    // Bespoke 700ms: a full-track gauge sweep needs more
                    // runway than V3Motion.slow or it reads as a blink.
                    : const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, swept, _) => LinearProgressIndicator(
                  value: swept,
                  minHeight: 9,
                  color: p.success,
                  backgroundColor: p.surfaceRaised,
                ),
              ),
            ),
            const SizedBox(height: 7),
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
                    style: TextStyle(color: p.inkMuted, fontSize: 11),
                  ),
                ),
                Text(
                  v3Copy(
                    context,
                    zh: '剩余 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                    en: '${controller.traffic.remainGb.toStringAsFixed(1)} GB left',
                    tw: '剩餘 ${controller.traffic.remainGb.toStringAsFixed(1)} GB',
                  ),
                  style: TextStyle(color: p.ink, fontSize: 11),
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
      );
    return flat
        ? content
        : _DashboardCard(
            padding: const EdgeInsets.all(V3Layout.cardPadding),
            child: content,
          );
  }
}

/// The protection badge's color (see [_protectionLabel] for the wording):
/// green once the tunnel is up, amber while busy, red only when a real fault
/// exposes the tunnel, quiet gray for plain idle.
Color _protectionColor(V3Palette p, ConnectionStatus status) => switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error => p.danger,
      ConnectionStatus.disconnected => p.inkMuted,
    };

/// Protection wording for the connection card's corner badge — not a
/// connection echo (the orb button already shows the live state).
String _protectionLabel(BuildContext context, ConnectionStatus status) =>
    switch (status) {
      ConnectionStatus.connected => v3Copy(
        context,
        zh: '保护中',
        en: 'Protected',
        tw: '保護中',
      ),
      ConnectionStatus.connecting || ConnectionStatus.disconnecting => v3Copy(
        context,
        zh: '处理中',
        en: 'Processing',
        tw: '處理中',
      ),
      ConnectionStatus.disconnected || ConnectionStatus.error => v3Copy(
        context,
        zh: '未保护',
        en: 'Unprotected',
        tw: '未保護',
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
  if (value > 0) {
    return '${(value / 1024).toStringAsFixed(value < 10240 ? 1 : 0)} KB';
  }
  return '0 MB';
}

String _duration(Duration d) =>
    '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

import 'dart:async';
import 'dart:math' as math;
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
import '../ui/v3_latency_tier.dart';
import '../ui/v3_locale_copy.dart';
import '../ui/v3_node_picker.dart';
import '../ui/v3_toast.dart';
import '../ui/v3_node_tags.dart';
import '../ui/v3_layout.dart';
import '../ui/v3_notice_bar.dart';
import '../ui/v3_notice_carousel.dart';

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
          // Phones: announcement images from the backend rotate in a card;
          // desktop keeps the slim ticker so the orb stays above the fold.
          if (v3UsesMergedConnectionCard(defaultTargetPlatform))
            V3NoticeCarousel(controller: controller)
          else
            V3NoticeBar(controller: controller),
          V3DashboardAlerts(controller: controller),
          if (confirmedNoPlan)
            _NoPlanDashboardPanel(controller: controller)
          else ...[
            if (v3UsesMergedConnectionCard(defaultTargetPlatform)) ...[
              _MobileConnectionCard(
                controller: controller,
                connected: status == ConnectionStatus.connected,
                connecting:
                    status == ConnectionStatus.connecting ||
                    status == ConnectionStatus.disconnecting,
              ),
              const SizedBox(height: 12),
            ] else ...[
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
            ],
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
              child: _ConnectIntroContent(
                controller: controller,
                status: status,
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
                Text(
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
                          // Same dialect as the picker's corner badge: one
                          // 「延迟：42ms」family, timeout included.
                          Text(
                            node.latency > 0 && node.latency < 9999
                                ? v3Copy(
                                    context,
                                    zh: '延迟：${node.latency}ms',
                                    en: 'Latency: ${node.latency}ms',
                                    tw: '延遲：${node.latency}ms',
                                  )
                                : node.latency >= 9999
                                ? v3Copy(
                                    context,
                                    zh: '延迟：超时',
                                    en: 'Latency: timeout',
                                    tw: '延遲：逾時',
                                  )
                                : node.latency == -1
                                ? v3Copy(
                                    context,
                                    zh: '测速中',
                                    en: 'Testing',
                                    tw: '測速中',
                                  )
                                : v3Copy(
                                    context,
                                    zh: '未测速',
                                    en: 'Not tested',
                                    tw: '未測速',
                                  ),
                            style: TextStyle(
                              color: v3LatencyInk(p, node.region, node.latency),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (node.tags.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            V3NodeTags(tags: node.tags, maxVisible: 2),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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

/// The orb section of the connection workspace: status header, the connect
/// orb and its caption over the faded world map. Shared by the desktop
/// workspace card and the phone's merged connection card.
class _ConnectIntroContent extends StatefulWidget {
  const _ConnectIntroContent({
    required this.controller,
    required this.status,
  });
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
    // The corner badge speaks protection, not connection: red while exposed,
    // lime once the tunnel is up. The orb button below carries the live state.
    final protectionColor = switch (status) {
      ConnectionStatus.connected => p.success,
      ConnectionStatus.connecting ||
      ConnectionStatus.disconnecting => p.warning,
      ConnectionStatus.error || ConnectionStatus.disconnected => p.danger,
    };
    // The caption below the orb cross-fades on state changes; compute it once
    // so the AnimatedSwitcher key and the Text share one source.
    final caption = connected
        ? v3Copy(context, zh: '断开连接', en: 'Disconnect', tw: '中斷連線')
        : connecting
        ? v3Copy(context, zh: '处理中', en: 'Processing', tw: '處理中')
        : v3Copy(context, zh: '点击开始连接', en: 'Tap to connect', tw: '點擊開始連線');
    return Stack(
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
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: V3StatusBadge(
                        key: ValueKey(status),
                        label: _protectionLabel(context, status),
                        color: protectionColor,
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
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                      begin: const Offset(0, 0.35),
                                      end: Offset.zero)
                                  .animate(animation),
                              child: child,
                            ),
                          ),
                          child: Text(
                            caption,
                            key: ValueKey(caption),
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _ConnectionDuration(controller: widget.controller),
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

/// The phone's connection card: orb section on top, the whole node row
/// tappable with a trailing chevron (no dedicated switch button), then the
/// routing segment. Three desktop cards become one mobile surface.
class _MobileConnectionCard extends StatefulWidget {
  const _MobileConnectionCard({
    required this.controller,
    required this.connected,
    required this.connecting,
  });
  final AppController controller;
  final bool connected;
  final bool connecting;

  @override
  State<_MobileConnectionCard> createState() => _MobileConnectionCardState();
}

class _MobileConnectionCardState extends State<_MobileConnectionCard>
    with _ModeSwitching {
  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final controller = widget.controller;
    final status = controller.connectionStatus;
    final node = controller.currentNode;
    final displayName = controller.autoSelected
        ? node.name.isEmpty
              ? v3Copy(context, zh: '自动选择', en: 'Automatic', tw: '自動選擇')
              : node.name
        : node.name.isEmpty
        ? v3Copy(context, zh: '尚未选择节点', en: 'No node selected', tw: '尚未選擇節點')
        : node.name;
    return _DashboardCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(V3Layout.cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              key: kConnectActionCardKey,
              height: 216,
              child: _ConnectIntroContent(
                controller: controller,
                status: status,
              ),
            ),
            Container(height: 1, color: p.line),
            // V3Pressable keeps the press ink above the card's opaque fill —
            // a bare InkWell paints it on the root Material below.
            V3Pressable(
              key: kCurrentNodeCardKey,
              onTap: () => V3NodePicker.show(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
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
                                    v3Copy(context,
                                      zh: '自动', en: 'Auto', tw: '自動'),
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
                                ? v3Copy(context,
                                    zh: '延迟：${node.latency}ms',
                                    en: 'Latency: ${node.latency}ms',
                                    tw: '延遲：${node.latency}ms')
                                : node.latency >= 9999
                                ? v3Copy(context,
                                    zh: '延迟：超时',
                                    en: 'Latency: timeout',
                                    tw: '延遲：逾時')
                                : node.latency == -1
                                ? v3Copy(context,
                                    zh: '测速中', en: 'Testing', tw: '測速中')
                                : v3Copy(context,
                                    zh: '未测速', en: 'Not tested', tw: '未測速'),
                            style: TextStyle(
                              color: v3LatencyInk(p, node.region, node.latency),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
            Container(height: 1, color: p.line),
            // The merged card makes its own context obvious; the routing
            // label would repeat what the segment already says.
            Padding(
              padding: const EdgeInsets.all(14),
              child: _ModeSegment<ProxyMode>(
                values: ProxyMode.values,
                label: _modeTitle,
                selected: controller.proxyMode,
                busy: _busy,
                onSelect: (mode) =>
                    _runModeSwitch(() => _setProxyMode(mode)),
                trackKey: 'v3-route-mode-track',
              ),
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
  });
  final AppController controller;
  final ConnectionStatus status;

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
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _breathe =
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  // One-shot success ripple (busy → connected).
  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _rippleEase =
      CurvedAnimation(parent: _ripple, curve: Curves.easeOutCubic);
  // One-shot error shake.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    // Mounting mid-connect (silent start): join the breathe loop, but never
    // fire one-shots on mount.
    if (_isBusy(widget.status)) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ConnectionOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Every AppScope notifyListeners rebuilds this subtree; only a real
    // status transition may touch the controllers.
    if (oldWidget.status == widget.status) return;
    final wasBusy = _isBusy(oldWidget.status);
    final isBusy = _isBusy(widget.status);
    if (isBusy && !wasBusy) {
      _pulse.repeat(reverse: true);
    } else if (!isBusy && wasBusy) {
      _pulse
        ..stop()
        ..value = 0;
    }
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
    final locked = controller.connectionActionLocked;
    final busy = _isBusy(status);
    final connected = status == ConnectionStatus.connected;
    final orbColor = switch (status) {
      ConnectionStatus.connected => p.citrus,
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
    return Semantics(
      key: kConnectOrbKey,
      button: true,
      enabled: !locked,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 86,
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // FX layer rides outside the tap target's bounds without taking
              // layout space: halo while busy, success ripple on connect.
              Positioned(
                left: -21,
                top: -21,
                width: 128,
                height: 128,
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
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  builder: (context, color, _) => SizedBox(
                    width: 86,
                    height: 86,
                    child: Material(
                      color: color!,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: locked
                            ? null
                            : () async {
                                // Failure remains a persistent alert with a retry action.
                                final error = await controller.toggleConnection();
                                if (error == null &&
                                    context.mounted &&
                                    controller.connectionStatus ==
                                        ConnectionStatus.connected) {
                                  V3Toast.show(context, v3Copy(context,
                                    zh: '连接成功', en: 'Connected', tw: '連線成功'),
                                    type: V3ToastType.success);
                                }
                              },
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween(begin: 0.85, end: 1.0)
                                    .animate(animation),
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
                                    key: ValueKey(connected ? 'orb-stop' : 'orb-power'),
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
  });
  final double breathe;
  final bool haloActive;
  final double ripple;
  final bool rippleActive;
  final Color haloColor;
  final Color rippleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (haloActive) {
      // Radius grows while the ring fades: a slow exhale, not a bounce.
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = haloColor.withValues(alpha: 0.10 + 0.28 * (1 - breathe));
      canvas.drawCircle(center, 45 + 8 * breathe, halo);
    }
    if (rippleActive && ripple > 0.0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * (1 - ripple) + 0.5
        ..color = rippleColor.withValues(alpha: 0.5 * (1 - ripple));
      canvas.drawCircle(center, 43 + 18 * ripple, ring);
    }
  }

  @override
  bool shouldRepaint(_OrbFxPainter oldDelegate) =>
      oldDelegate.breathe != breathe ||
      oldDelegate.ripple != ripple ||
      oldDelegate.haloActive != haloActive ||
      oldDelegate.rippleActive != rippleActive ||
      oldDelegate.haloColor != haloColor ||
      oldDelegate.rippleColor != rippleColor;
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

/// Phones merge connection, node and routing into one card; desktop keeps
/// the three-surface workspace.
bool v3UsesMergedConnectionCard(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;

class _ModeRail extends StatefulWidget {
  const _ModeRail({required this.controller});
  final AppController controller;

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
    final error = await _modeController.setProxyMode(mode);
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
    return _DashboardCard(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
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
          Expanded(child: AnimatedContainer(
            key: optionKey == null
                ? null : ValueKey<String>(optionKey!(value)),
            duration: const Duration(milliseconds: 150),
            alignment: Alignment.center,
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
            // V3Pressable rides inside the option so the press ink lands on
            // the option surface instead of on a Material beneath the card
            // fill. The padding lives inside it so the ink still covers the
            // full option rect, as the old wrapping InkWell did.
            child: V3Pressable(
              onTap: busy || value == selected ? null : () => onSelect(value),
              borderRadius: BorderRadius.circular(V3Radius.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: SizedBox(
                  width: double.infinity,
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
              ),
            ),
          )),
      ]),
    );
  }
}


/// The session card: four gauges in one row on desktop, a 2x2 grid on
/// phones. The reachability strip is appended on desktop only — a phone's
/// slots are far too narrow for four sites.
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
          // One shared cell inset keeps the columns on the same grid:
          // every label starts at the same offset from its divider.
          Widget cell(Widget metric) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: metric,
            ),
          );
          Widget divider() => Container(width: 1, height: 38, color: p.line);
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
          // The reachability strip is a desktop presentation: phone slots
          // are far too narrow for four sites, so the phone card ends at
          // the gauges.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gauge,
              if (!compact) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: p.line),
                const SizedBox(height: 10),
                _ConnectivityRow(controller: controller),
              ],
            ],
          );
        },
          ),
        ],
      ),
    );
  }
}

/// The reachability strip lives inside [_SessionMetrics] on desktop only —
/// the phone's merged connection card does not render it.
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
  // The 30s re-probe cadence replaces the old manual refresh button.
  static const Duration _reprobeInterval = Duration(seconds: 30);
  Timer? _reprobeTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _lastStatus = widget.controller.connectionStatus;
    // Restored/silent-start sessions mount already connected: probe once the
    // first frame exists so the strip never sits empty while connected.
    if (_lastStatus == ConnectionStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            widget.controller.connectionStatus == ConnectionStatus.connected) {
          unawaited(_runCheck());
        }
      });
      _syncReprobe(true);
    }
  }

  // The 30s re-probe only ticks while connected and is cancelled the moment
  // the connection leaves — the automated replacement for the refresh button.
  void _syncReprobe(bool connected) {
    if (connected) {
      _reprobeTimer ??= Timer.periodic(_reprobeInterval, (_) {
        if (!mounted) return;
        if (widget.controller.connectionStatus != ConnectionStatus.connected) {
          return;
        }
        unawaited(_runCheck());
      });
    } else {
      _reprobeTimer?.cancel();
      _reprobeTimer = null;
    }
  }

  @override
  void dispose() {
    _reprobeTimer?.cancel();
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
    _syncReprobe(status == ConnectionStatus.connected);
    if (status != ConnectionStatus.connected && _results.isNotEmpty) {
      setState(_results.clear);
    }
    if (becameConnected && !_running) {
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
    final status = widget.controller.connectionStatus;
    // Fixed height, always four slots: nothing in this row can change its
    // height, so the plan card below never shifts when a probe starts. The
    // 12px cell insets and 1px dividers mirror the gauge row above, so both
    // rows read as one grid.
    return SizedBox(
      key: const ValueKey('v3-connectivity-strip'),
      height: 16,
      child: Row(
        children: [
          for (var i = 0; i < _targets.length; i++) ...[
            if (i > 0) Container(width: 1, height: 16, color: p.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ConnectivitySite(
                  target: _targets[i],
                  phase: _phaseFor(status, i),
                  result: _results[i],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _SitePhase _phaseFor(ConnectionStatus status, int index) {
    switch (status) {
      case ConnectionStatus.connecting:
      case ConnectionStatus.disconnecting:
        return _SitePhase.checking;
      case ConnectionStatus.connected:
        final r = _results[index];
        if (r == null) return _SitePhase.checking;
        return r.ok ? _SitePhase.ok : _SitePhase.failed;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        return _SitePhase.disconnected;
    }
  }
}

/// Well-known glyphs for the probe targets. Material's icon set has no
/// brand logos, so each site gets its closest recognizable stand-in.
IconData _siteIcon(String name) => switch (name) {
  'Google' => Icons.public_rounded,
  'YouTube' => Icons.play_circle_fill_rounded,
  'GitHub' => Icons.code_rounded,
  'ChatGPT' => Icons.auto_awesome_rounded,
  _ => Icons.language_rounded,
};

enum _SitePhase { disconnected, checking, ok, failed }

class _ConnectivitySite extends StatelessWidget {
  const _ConnectivitySite({
    required this.target,
    required this.phase,
    required this.result,
  });
  final ConnectivityTarget target;
  final _SitePhase phase;
  final ConnectivityResult? result;

  @override
  Widget build(BuildContext context) {
    final p = V3Palette.of(context);
    final r = result;
    final (dotColor, statusLine, statusColor) = switch (phase) {
      _SitePhase.disconnected => (
        p.danger,
        v3Copy(context, zh: '未连接', en: 'Offline', tw: '未連線'),
        p.dangerInk,
      ),
      _SitePhase.checking => (
        p.warning,
        v3Copy(context, zh: '检测中', en: 'Probing', tw: '檢測中'),
        p.warningInk,
      ),
      _SitePhase.ok => (
        p.success,
        '${r!.latencyMs} ms',
        p.successInk,
      ),
      _SitePhase.failed => (
        p.danger,
        v3Copy(context, zh: '不通', en: 'Blocked', tw: '不通'),
        p.dangerInk,
      ),
    };
    // Inline tile on a fixed grid: icon and name anchor the left edge, the
    // lamp dot and a fixed-width right-aligned status cell anchor the right.
    // Name length no longer shifts the dot, so all four dots sit on one
    // vertical rhythm and results landing never jiggle the row. The icon is
    // a quiet always-visible mark; the dot is the lamp — its color and the
    // status text transition, so a probe outcome change reads as a soft
    // cross-fade instead of a hard swap.
    return Row(
      children: [
        Icon(_siteIcon(target.name), color: p.inkMuted, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            target.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.ink, fontSize: 10,
              fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 3),
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: dotColor),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          builder: (context, color, _) => Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color!, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 3),
        SizedBox(
          width: 40,
          child: Align(
            alignment: Alignment.centerRight,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // Keyed by phase: a re-probe with the same outcome never fades,
              // a real change (12 ms → 不通) cross-fades in place.
              child: Text(
                statusLine,
                key: ValueKey(phase),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: statusColor, fontSize: 10),
              ),
            ),
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
                      // An active plan needs no status word - the green
                      // countdown already says it. Abnormal states earn the
                      // suffix, except 到期: the expiry label already opens
                      // with that word.
                      plan.usable || plan.status == '到期'
                          ? plan.expiry
                          : '${plan.expiry} · ${plan.status}',
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

import 'dart:async';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/filter_tabs.dart';
import '../../shared/widgets/page_header.dart';
import '../../shared/widgets/search_input.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});

  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  static const _tabs = ['全部', '收藏', 'VIP', '亚洲', '欧洲', '美洲', '大洋洲'];
  int _tab = 0;
  String _query = '';
  String? _selectedId;
  final Set<String> _favorites = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AppScope.of(context);
    _selectedId ??= ctrl.currentNode.id;
  }

  List<NodeModel> get _filtered {
    final nodes = AppScope.of(context).nodes;
    return nodes.where((n) {
      if (_query.isNotEmpty &&
          !n.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      switch (_tabs[_tab]) {
        case '收藏':
          return _favorites.contains(n.id);
        case 'VIP':
          return n.tags.contains('Premium');
        case '亚洲':
          return n.region == NodeRegion.asia;
        case '欧洲':
          return n.region == NodeRegion.europe;
        case '美洲':
          return n.region == NodeRegion.america;
        case '大洋洲':
          return n.region == NodeRegion.oceania;
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final ctrl = AppScope.of(context);
    final isAuto = ctrl.autoSelected;
    final effectiveId = isAuto
        ? '__auto__'
        : (_selectedId ?? ctrl.currentNode.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(title: '节点', subtitle: '选择适合你的高速线路'),
        const SizedBox(height: 12),
        // Search + refresh row
        Row(
          children: [
            Expanded(
              child: SearchInput(
                hintText: '搜索节点',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(width: 12),
            _RefreshButton(ctrl: ctrl),
          ],
        ),
        const SizedBox(height: 14),
        // Smart recommendation card (always visible)
        _AutoCard(
          ctrl: ctrl,
          selected: isAuto,
          onTap: () {
            setState(() => _selectedId = null);
            ctrl.selectAuto();
            AppToast.show(
              context,
              '已开启自动选择，将使用最优节点',
              type: AppToastType.success,
            );
          },
        ),
        const SizedBox(height: 12),
        FilterTabs(
          tabs: _tabs,
          selectedIndex: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final cols = w >= 620 ? 3 : (w >= 440 ? 2 : 1);
              final nodes = _filtered;
              if (nodes.isEmpty) {
                return Center(
                  child: Text(
                    '没有匹配的节点',
                    style: AppTextStyles.body.copyWith(color: c.textMuted),
                  ),
                );
              }
              return GridView.builder(
                padding: EdgeInsets.zero,
                itemCount: nodes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  mainAxisExtent: 118,
                ),
                itemBuilder: (context, i) {
                  final n = nodes[i];
                  return _NodeCard(
                    node: n,
                    selected: !isAuto && n.id == effectiveId,
                    favorite: _favorites.contains(n.id),
                    onTap: () async {
                      setState(() => _selectedId = n.id);
                      final error = await ctrl.setCurrentNode(n);
                      if (!mounted) return;
                      if (error != null) {
                        // ignore: use_build_context_synchronously
                        AppToast.show(context, error, type: AppToastType.error);
                      } else {
                        // ignore: use_build_context_synchronously
                        AppToast.show(context, '已切换至 ${n.name}', type: AppToastType.success);
                      }
                    },
                    onToggleFavorite: () => setState(() {
                      if (!_favorites.add(n.id)) _favorites.remove(n.id);
                    }),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Smart recommendation card ──────────────────────────────────────────────

class _AutoCard extends StatelessWidget {
  const _AutoCard({
    required this.ctrl,
    required this.selected,
    required this.onTap,
  });

  final AppController ctrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final nodes = ctrl.nodes;
    final tested = nodes
        .where((n) => n.latency > 0 && n.latency < 9999)
        .toList();
    final testing = nodes.any((n) => n.latency == -1);

    // Find best node for display
    NodeModel? best;
    for (final n in tested) {
      if (best == null || n.latency < best.latency) best = n;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? c.primary : c.softBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          colors: [c.primary, c.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : c.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  LucideIcons.zap,
                  size: 16,
                  color: selected ? Colors.white : c.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动选择',
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (testing && best == null)
                      _TestingDots(color: c.textMuted)
                    else if (best != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CountryFlag.fromCountryCode(
                            best.code.isNotEmpty ? best.code : 'UN',
                            theme: const ImageTheme(
                              width: 18,
                              height: 13,
                              shape: RoundedRectangle(2),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${best.name} · ${best.latency} ms',
                            style: AppTextStyles.caption.copyWith(
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '暂无可用节点',
                        style: AppTextStyles.caption.copyWith(
                          color: c.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              // Latency summary badge
              if (tested.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _bestColor(best?.latency, c).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    best != null ? '${best.latency} ms' : '--',
                    style: AppTextStyles.badge.copyWith(
                      color: _bestColor(best?.latency, c),
                      fontSize: 11,
                    ),
                  ),
                )
              else if (testing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: c.primary,
                  ),
                ),
              const SizedBox(width: 8),
              if (selected)
                Icon(LucideIcons.circleCheck, size: 18, color: c.primary),
            ],
          ),
        ),
      ),
    );
  }

  Color _bestColor(int? ms, AppColors c) {
    if (ms == null) return c.textMuted;
    if (ms < 60) return c.success;
    if (ms < 150) return c.warning;
    return c.danger;
  }
}

// Animated "测速中..." dots
class _TestingDots extends StatefulWidget {
  const _TestingDots({required this.color});
  final Color color;
  @override
  State<_TestingDots> createState() => _TestingDotsState();
}

class _TestingDotsState extends State<_TestingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final dots = '.' * ((_ctrl.value * 4).floor() % 4);
        return Text(
          '测速中$dots',
          style: AppTextStyles.caption.copyWith(color: widget.color),
        );
      },
    );
  }
}

// ── Refresh button ─────────────────────────────────────────────────────────

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.ctrl});
  final AppController ctrl;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
    _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    unawaited(_spin.repeat());
    AppToast.show(context, '正在刷新节点并测速…', type: AppToastType.info);
    await widget.ctrl.refreshNodes();
    if (mounted) {
      _spin.stop();
      setState(() => _loading = false);
      AppToast.show(context, '节点已更新，测速进行中', type: AppToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.user),
            border: Border.all(color: c.softBorder),
          ),
          child: RotationTransition(
            turns: _spin,
            child: Icon(
              LucideIcons.refreshCw,
              size: 18,
              color: _loading ? c.primary : c.iconDefault,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Node card ──────────────────────────────────────────────────────────────

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final NodeModel node;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final code = node.code.isNotEmpty ? node.code : 'UN';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: selected ? c.primary : c.softBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: SVG flag + node name + star
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CountryFlag.fromCountryCode(
                    code,
                    theme: const ImageTheme(
                      width: 28,
                      height: 20,
                      shape: RoundedRectangle(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        color: selected ? c.primary : c.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onToggleFavorite,
                    child: Icon(
                      LucideIcons.star,
                      size: 15,
                      color: favorite ? c.warning : c.iconMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // English name subtitle
              if (node.englishName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: Text(
                    node.englishName,
                    style: AppTextStyles.caption.copyWith(
                      color: c.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              const Spacer(),
              // Bottom row: latency + badge + checkmark
              Row(
                children: [
                  _LatencyIndicator(latency: node.latency),
                  const Spacer(),
                  if (node.tags.contains('Premium')) ...[
                    AppBadge.premium(context),
                    const SizedBox(width: 6),
                  ],
                  if (selected)
                    Icon(LucideIcons.circleCheck, size: 16, color: c.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatencyIndicator extends StatelessWidget {
  const _LatencyIndicator({required this.latency});
  final int latency;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (latency == -1) {
      // Testing
      return Row(
        children: [
          SizedBox(
            width: 8,
            height: 8,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: c.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '测速中',
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      );
    }
    if (latency == 0 || latency >= 9999) {
      return Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: c.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text('--', style: AppTextStyles.menu.copyWith(color: c.textMuted)),
        ],
      );
    }
    final color = latency < 60
        ? c.success
        : (latency < 150 ? c.warning : c.danger);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$latency ms', style: AppTextStyles.menu.copyWith(color: color)),
      ],
    );
  }
}

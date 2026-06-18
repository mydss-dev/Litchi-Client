import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/app_controller.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_shadows.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_toast.dart';

Future<void> showDesktopNodePicker(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => const _DesktopNodePickerDialog(),
  );
}

class _DesktopNodePickerDialog extends StatefulWidget {
  const _DesktopNodePickerDialog();

  @override
  State<_DesktopNodePickerDialog> createState() =>
      _DesktopNodePickerDialogState();
}

class _DesktopNodePickerDialogState extends State<_DesktopNodePickerDialog> {
  static const _tabs = ['全部', 'VIP', '亚洲', '欧洲', '美洲', '大洋洲'];

  int _tab = 0;
  String _query = '';

  List<NodeModel> _filteredNodes(AppController ctrl) {
    final key = _query.trim().toLowerCase();
    return ctrl.nodes.where((node) {
      if (key.isNotEmpty) {
        final matchesSearch =
            node.name.toLowerCase().contains(key) ||
            node.englishName.toLowerCase().contains(key) ||
            node.code.toLowerCase().contains(key);
        if (!matchesSearch) return false;
      }
      return switch (_tabs[_tab]) {
        'VIP' => node.tags.contains('Premium'),
        '亚洲' => node.region == NodeRegion.asia,
        '欧洲' => node.region == NodeRegion.europe,
        '美洲' => node.region == NodeRegion.america,
        '大洋洲' => node.region == NodeRegion.oceania,
        _ => true,
      };
    }).toList();
  }

  Future<void> _selectAuto(AppController ctrl) async {
    final error = await ctrl.selectAuto();
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      error ?? '已开启自动选择',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  Future<void> _selectNode(AppController ctrl, NodeModel node) async {
    final error = await ctrl.setCurrentNode(node);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      error ?? '已切换到 ${node.name}',
      type: error == null ? AppToastType.success : AppToastType.error,
    );
  }

  void _testLatencies(AppController ctrl) {
    if (ctrl.nodes.isEmpty) {
      AppToast.show(context, '暂无可测速节点', type: AppToastType.warning);
      return;
    }
    ctrl.testLatencies();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);
    final c = AppColors.of(context);
    final nodes = _filteredNodes(ctrl);
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width - 48).clamp(360.0, 620.0).toDouble();
    final dialogHeight = (screen.height - 64).clamp(460.0, 540.0).toDouble();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogWidth),
          child: SizedBox(
            height: dialogHeight,
            child: Container(
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: c.softBorder),
                boxShadow: AppShadows.card(c),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogHeader(
                    nodeCount: ctrl.nodes.length,
                    onTest: () => _testLatencies(ctrl),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _SearchField(
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RegionTabs(
                    tabs: _tabs,
                    selected: _tab,
                    onSelected: (index) => setState(() => _tab = index),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: CustomScrollView(
                      shrinkWrap: true,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                          sliver: SliverToBoxAdapter(
                            child: _AutoSelectTile(
                              selected: ctrl.autoSelected,
                              onTap: () => _selectAuto(ctrl),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),
                        if (nodes.isEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            sliver: SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: 22,
                                  bottom: 22,
                                ),
                                child: _NodeEmptyState(
                                  searching:
                                      _query.trim().isNotEmpty || _tab != 0,
                                ),
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            sliver: SliverGrid.builder(
                              itemCount: nodes.length,
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 290,
                                    mainAxisExtent: 78,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                  ),
                              itemBuilder: (context, index) {
                                final node = nodes[index];
                                return _NodeTile(
                                  node: node,
                                  selected:
                                      !ctrl.autoSelected &&
                                      ctrl.currentNode.id == node.id,
                                  onTap: () => _selectNode(ctrl, node),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.nodeCount, required this.onTest});

  final int nodeCount;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(LucideIcons.route, size: 18, color: c.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择节点',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: c.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nodeCount > 0
                      ? '$nodeCount 个节点 · 筛选线路并查看延迟'
                      : '暂无节点 · 请检查订阅状态',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            tooltip: '测速',
            icon: LucideIcons.gauge,
            onTap: onTest,
            color: c.primary,
          ),
          const SizedBox(width: 4),
          _HeaderIconButton(
            tooltip: '关闭',
            icon: LucideIcons.x,
            onTap: () => Navigator.of(context).pop(),
            color: c.iconMuted,
          ),
        ],
      ),
    );
  }
}

class _NodeEmptyState extends StatelessWidget {
  const _NodeEmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: c.softBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              searching ? LucideIcons.searchX : LucideIcons.globe2,
              size: 20,
              color: c.iconMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            searching ? '没有匹配的节点' : '暂无节点',
            style: AppTextStyles.bodyStrong.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            searching ? '换个关键词或分类再试试' : '如果刚登录，请稍等订阅数据加载完成',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.input.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        hintText: '搜索节点',
        hintStyle: AppTextStyles.input.copyWith(color: c.textMuted),
        filled: true,
        fillColor: c.cardBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: c.softBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: c.softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: c.primary),
        ),
      ),
    );
  }
}

class _RegionTabs extends StatelessWidget {
  const _RegionTabs({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = selected == index;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? c.primary : c.cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: active ? c.primary : c.softBorder),
                ),
                child: Text(
                  tabs[index],
                  style: AppTextStyles.caption.copyWith(
                    color: active ? Colors.white : c.textSecondary,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AutoSelectTile extends StatelessWidget {
  const _AutoSelectTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _NodeIcon(icon: LucideIcons.zap, selected: selected),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动选择',
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '根据延迟自动使用更优线路',
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          if (selected)
            Icon(LucideIcons.circleCheck, color: c.primary, size: 19),
        ],
      ),
    );
  }
}

class _NodeTile extends StatelessWidget {
  const _NodeTile({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final NodeModel node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return _SelectableSurface(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          _FlagBox(node: node),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  node.englishName.isEmpty
                      ? _regionLabel(node.region)
                      : node.englishName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          _Latency(latency: node.latency),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.circleCheck, color: c.primary, size: 19),
          ],
        ],
      ),
    );
  }

  String _regionLabel(NodeRegion region) => switch (region) {
    NodeRegion.asia => '亚洲',
    NodeRegion.europe => '欧洲',
    NodeRegion.america => '美洲',
    NodeRegion.oceania => '大洋洲',
  };
}

class _SelectableSurface extends StatelessWidget {
  const _SelectableSurface({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.primarySoft : c.cardBg,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: selected ? c.primary : c.softBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NodeIcon extends StatelessWidget {
  const _NodeIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.cardBg : c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: c.primary, size: 19),
    );
  }
}

class _FlagBox extends StatelessWidget {
  const _FlagBox({required this.node});

  final NodeModel node;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: node.code.isEmpty
          ? Icon(LucideIcons.globe2, size: 19, color: c.primary)
          : CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 26,
                height: 18,
                shape: RoundedRectangle(4),
              ),
            ),
    );
  }
}

class _Latency extends StatelessWidget {
  const _Latency({required this.latency});

  final int latency;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (latency == -1) {
      return SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.warning),
      );
    }
    if (latency <= 0 || latency >= 9999) {
      return Text(
        '--',
        style: AppTextStyles.caption.copyWith(color: c.textMuted),
      );
    }
    final color = latency < 150 ? c.success : c.danger;
    return Text(
      '$latency ms',
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

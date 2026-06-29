import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/app_controller.dart';
import '../../shared/models/app_models.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/app_radius.dart';
import '../../shared/theme/app_shadows.dart';
import '../../shared/theme/app_text_styles.dart';
import '../../shared/utils/latency_status.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_toast.dart';

Future<void> showMobileNodePicker(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    builder: (_) => const _MobileNodePickerSheet(),
  );
}

class _MobileNodePickerSheet extends StatefulWidget {
  const _MobileNodePickerSheet();

  @override
  State<_MobileNodePickerSheet> createState() => _MobileNodePickerSheetState();
}

class _MobileNodePickerSheetState extends State<_MobileNodePickerSheet> {
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final nodes = _filteredNodes(ctrl);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.86,
        minChildSize: 0.58,
        maxChildSize: 0.94,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              border: Border(top: BorderSide(color: c.softBorder)),
              boxShadow: AppShadows.soft(c),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.softBorder,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                    child: Row(
                      children: [
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
                                '筛选线路并查看延迟',
                                style: AppTextStyles.caption.copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '测速',
                          onPressed: () => _testLatencies(ctrl),
                          icon: Icon(LucideIcons.gauge, color: c.primary),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(LucideIcons.x, color: c.iconMuted),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      style: AppTextStyles.input.copyWith(color: c.textPrimary),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        hintText: '搜索节点',
                        hintStyle: AppTextStyles.input.copyWith(
                          color: c.textMuted,
                        ),
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
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RegionTabs(
                    tabs: _tabs,
                    selected: _tab,
                    onSelected: (index) => setState(() => _tab = index),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                      children: [
                        _AutoSelectTile(
                          selected: ctrl.autoSelected,
                          onTap: () => _selectAuto(ctrl),
                        ),
                        const SizedBox(height: 10),
                        if (nodes.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 48),
                            child: Center(
                              child: Text(
                                '暂无节点',
                                style: AppTextStyles.body.copyWith(
                                  color: c.textMuted,
                                ),
                              ),
                            ),
                          )
                        else
                          for (final node in nodes) ...[
                            _NodeTile(
                              node: node,
                              selected:
                                  !ctrl.autoSelected &&
                                  ctrl.currentNode.id == node.id,
                              onTap: () => _selectNode(ctrl, node),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final active = selected == index;
          return GestureDetector(
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
                const Text('自动选择', style: AppTextStyles.bodyStrong),
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
            color: selected ? c.primarySoft : null,
            gradient: selected ? null : c.cardGradient,
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
      child: node.code.isNotEmpty
          ? CountryFlag.fromCountryCode(
              node.code,
              theme: const ImageTheme(
                width: 27,
                height: 19,
                shape: RoundedRectangle(3),
              ),
            )
          : Icon(LucideIcons.globe2, color: c.iconMuted, size: 19),
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
    if (latency <= 0) {
      return Text(
        '--',
        style: AppTextStyles.caption.copyWith(color: c.textMuted),
      );
    }
    final color = LatencyStatus.color(latency, c);
    return Text(
      LatencyStatus.label(latency),
      style: AppTextStyles.caption.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

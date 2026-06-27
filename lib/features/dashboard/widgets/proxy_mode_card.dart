import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../shared/models/app_models.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_selector.dart';
import '../../../shared/widgets/app_toast.dart';

class ProxyModeCard extends StatelessWidget {
  const ProxyModeCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // Rebuild only when the proxy mode or core-running state changes.
    return AppSelector<ProxyMode>(
      selector: (ctrl) => ctrl.proxyMode,
      builder: (context, proxyMode, _) {
        final description = switch (proxyMode) {
          ProxyMode.rule   => '自动分流，国内直连、国外流量走代理',
          ProxyMode.global => '所有流量均通过代理节点转发',
          ProxyMode.direct => '不使用代理，直接连接目标网站',
        };
        return AppCard(
          radius: AppRadius.card,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '代理模式',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: c.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: c.textMuted),
              ),
              const SizedBox(height: 16),
              _ProxyModeSegment(
                value: proxyMode,
                onChanged: (mode) async {
                  final ctrl = AppScope.read(context);
                  if (mode == ctrl.proxyMode) return;
                  final wasRunning = ctrl.coreRunning;
                  final error = await ctrl.setProxyMode(mode);
                  if (!context.mounted) return;
                  if (error != null) {
                    AppToast.show(
                      context,
                      error,
                      type: AppToastType.error,
                    );
                  } else if (wasRunning) {
                    AppToast.show(
                      context,
                      '已切换至 ${mode.label}',
                      type: AppToastType.success,
                    );
                  } else {
                    AppToast.show(context, '代理模式将在下次连接后生效');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProxyModeSegment extends StatelessWidget {
  const _ProxyModeSegment({required this.value, required this.onChanged});

  final ProxyMode value;
  final ValueChanged<ProxyMode> onChanged;

  static const _items = [
    _ProxyModeItem(label: '规则', mode: ProxyMode.rule),
    _ProxyModeItem(label: '全局', mode: ProxyMode.global),
    _ProxyModeItem(label: '直连', mode: ProxyMode.direct),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _ProxyModeOption(
                item: item,
                selected: item.mode == value,
                onTap: () => onChanged(item.mode),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProxyModeOption extends StatelessWidget {
  const _ProxyModeOption({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _ProxyModeItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? c.cardBg : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: c.primary.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.button.copyWith(
              color: selected ? c.primary : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProxyModeItem {
  const _ProxyModeItem({required this.label, required this.mode});

  final String label;
  final ProxyMode mode;
}

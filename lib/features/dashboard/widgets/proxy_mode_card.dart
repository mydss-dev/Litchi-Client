import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../l10n/l10n.dart';
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
          ProxyMode.rule => context.l10n.proxyModeDescriptionRule,
          ProxyMode.global => context.l10n.proxyModeDescriptionGlobal,
          ProxyMode.direct => context.l10n.proxyModeDescriptionDirect,
        };
        return AppCard(
          radius: AppRadius.card,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.proxyMode,
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
                    AppToast.show(context, error, type: AppToastType.error);
                  } else if (wasRunning) {
                    AppToast.show(
                      context,
                      context.l10n.switchedProxyMode(
                        _proxyModeLabel(context, mode),
                      ),
                      type: AppToastType.success,
                    );
                  } else {
                    AppToast.show(
                      context,
                      context.l10n.proxyModeNextConnection,
                    );
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
          for (final item in [
            _ProxyModeItem(label: context.l10n.ruleMode, mode: ProxyMode.rule),
            _ProxyModeItem(
              label: context.l10n.globalMode,
              mode: ProxyMode.global,
            ),
            _ProxyModeItem(
              label: context.l10n.directMode,
              mode: ProxyMode.direct,
            ),
          ])
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

String _proxyModeLabel(BuildContext context, ProxyMode mode) => switch (mode) {
  ProxyMode.rule => context.l10n.ruleMode,
  ProxyMode.global => context.l10n.globalMode,
  ProxyMode.direct => context.l10n.directMode,
};

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

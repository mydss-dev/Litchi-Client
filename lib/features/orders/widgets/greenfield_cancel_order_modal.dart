import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_modal.dart';

class GreenfieldCancelOrderModal extends StatefulWidget {
  const GreenfieldCancelOrderModal({super.key, required this.orderNo});

  final String orderNo;

  @override
  State<GreenfieldCancelOrderModal> createState() =>
      _GreenfieldCancelOrderModalState();
}

class _GreenfieldCancelOrderModalState
    extends State<GreenfieldCancelOrderModal> {
  bool _submitting = false;

  void _confirm() {
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.cancelOrder,
      subtitle: widget.orderNo.isEmpty
          ? null
          : context.l10n.orderNumber(widget.orderNo),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.dangerSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: c.danger.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.circleAlert, size: 18, color: c.danger),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.cancelOrderConfirm,
                    style: AppTextStyles.body.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: context.l10n.thinkAgain,
                  variant: AppButtonVariant.outline,
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  expand: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: _submitting
                      ? context.l10n.processing
                      : context.l10n.confirmCancel,
                  leadingIcon: LucideIcons.trash2,
                  variant: AppButtonVariant.danger,
                  loading: _submitting,
                  onPressed: _submitting ? null : _confirm,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

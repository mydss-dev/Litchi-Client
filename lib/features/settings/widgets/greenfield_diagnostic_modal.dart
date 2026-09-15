import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_radius.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_modal.dart';
import '../../../shared/widgets/app_toast.dart';

class GreenfieldDiagnosticModal extends StatelessWidget {
  const GreenfieldDiagnosticModal({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AppAdaptiveModal(
      title: context.l10n.diagnostics,
      subtitle: context.l10n.diagnosticCopyDescription,
      maxWidth: 720,
      maxHeightFactor: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 420),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: c.softBorder),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: context.l10n.copyDiagnostics,
            leadingIcon: LucideIcons.copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              AppToast.show(
                context,
                context.l10n.diagnosticCopied,
                type: AppToastType.success,
              );
            },
            expand: true,
          ),
        ],
      ),
    );
  }
}

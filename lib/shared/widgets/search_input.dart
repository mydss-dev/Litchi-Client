import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../l10n/l10n.dart';
import '../layout/app_control_metrics.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon_button.dart';

/// Shared search field using the same pointer/touch geometry as the rest of
/// the cross-platform control system.
class SearchInput extends StatefulWidget {
  const SearchInput({
    super.key,
    this.hintText,
    this.controller,
    this.onChanged,
  });

  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final TextEditingController _ctrl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _ctrl.text.isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final height = AppControlMetrics.regularHeight;

    return Container(
      height: height,
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.softBorder),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 16, color: c.iconMuted),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: AppTextStyles.body.copyWith(color: c.textPrimary),
              cursorColor: c.primary,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText ?? context.l10n.search,
                hintStyle: AppTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ),
          ),
          if (_hasText)
            AppIconButton(
              icon: LucideIcons.x,
              onPressed: _clear,
              tooltip: context.l10n.close,
              compact: true,
            )
          else
            const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }
}

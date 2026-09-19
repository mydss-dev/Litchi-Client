import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../l10n/app_locale_preference.dart';
import '../theme/v3_palette.dart';
import 'v3_locale_copy.dart';

/// Uses the same AppController language preference as the MaterialApp locale.
/// The system option deliberately passes null through to MaterialApp, rather
/// than freezing the language detected when the settings page first opens.
class V3LanguageSelector extends StatelessWidget {
  const V3LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    // Standalone previews share the same localization fallback as V3 copy.
    final l = v3Localizations(context);
    final p = V3Palette.of(context);
    return Semantics(
      label: l.language,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          border: Border.all(color: p.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AppLocalePreference>(
            key: const ValueKey('v3-language-select'),
            isExpanded: true,
            value: controller.language,
            dropdownColor: p.surface,
            items: [
              DropdownMenuItem(
                value: AppLocalePreference.system,
                child: Text(l.followSystem),
              ),
              DropdownMenuItem(
                value: AppLocalePreference.simplifiedChinese,
                child: Text(l.simplifiedChinese),
              ),
              DropdownMenuItem(
                value: AppLocalePreference.traditionalChinese,
                child: Text(l.traditionalChinese),
              ),
              DropdownMenuItem(
                value: AppLocalePreference.english,
                child: Text(l.english),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.setLanguage(value);
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import 'greenfield_settings_page.dart';

/// Compatibility entry retained for existing navigation references.
/// Runtime presentation is owned by GreenfieldSettingsPage.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldSettingsPage();
}

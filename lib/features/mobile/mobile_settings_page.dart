import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../shared/theme/app_text_styles.dart';

class MobileSettingsPage extends StatelessWidget {
  const MobileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = AppScope.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('设置', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('深色模式'),
          value: ctrl.isDark,
          onChanged: ctrl.toggleDarkMode,
        ),
        SwitchListTile(
          title: const Text('开发者模式'),
          value: ctrl.devMode,
          onChanged: ctrl.setDevMode,
        ),
        ListTile(title: const Text('模式'), subtitle: Text(ctrl.proxyMode.label)),
        ListTile(title: const Text('网络'), subtitle: Text(ctrl.networkMode.label)),
        ListTile(title: const Text('端口'), subtitle: Text(ctrl.proxyPort.toString())),
      ],
    );
  }
}

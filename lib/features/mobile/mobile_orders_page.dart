import 'package:flutter/material.dart';

import '../../shared/theme/app_text_styles.dart';

class MobileOrdersPage extends StatelessWidget {
  const MobileOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Text('订单', style: AppTextStyles.pageTitle.copyWith(fontSize: 26)),
        const SizedBox(height: 16),
        const ListTile(
          title: Text('订单记录'),
          subtitle: Text('移动端订单页面已创建，后续接订单 API 列表。'),
        ),
      ],
    );
  }
}

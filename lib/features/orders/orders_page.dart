import 'package:flutter/material.dart';

import '../../shared/widgets/app_modal.dart';
import 'greenfield_orders_page.dart';

/// Public Account Hub entry preserved for existing callers.
Future<void> showOrdersModal(BuildContext context) {
  return showAppAdaptiveModal<void>(
    context: context,
    builder: (_) => const OrdersPage(modal: true),
  );
}

/// Compatibility entry retained for AppShell and navigation callers.
/// The legacy order-card presentation tree has been removed; runtime rendering
/// is owned entirely by [GreenfieldOrdersPage].
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key, this.modal = false});

  final bool modal;

  @override
  Widget build(BuildContext context) => GreenfieldOrdersPage(modal: modal);
}

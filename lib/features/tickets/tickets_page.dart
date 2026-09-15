import 'package:flutter/widgets.dart';

import 'greenfield_tickets_page.dart';

/// Compatibility entry retained for existing navigation references.
/// Runtime presentation is owned by GreenfieldTicketsPage.
class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldTicketsPage();
}

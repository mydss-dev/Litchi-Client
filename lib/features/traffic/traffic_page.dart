import 'package:flutter/material.dart';

import 'greenfield_traffic_page.dart';

/// Compatibility entry retained for AppShell and navigation callers.
/// The legacy desktop/compact Traffic presentation trees have been removed;
/// runtime rendering is owned entirely by [GreenfieldTrafficPage].
class TrafficPage extends StatelessWidget {
  const TrafficPage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldTrafficPage();
}

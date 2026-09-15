import 'package:flutter/material.dart';

import 'greenfield_invite_page.dart';

/// Compatibility entry retained for AppShell and navigation callers.
/// The legacy desktop/compact Invite presentation trees have been removed;
/// runtime rendering is owned entirely by [GreenfieldInvitePage].
class InvitePage extends StatelessWidget {
  const InvitePage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldInvitePage();
}

import 'package:flutter/material.dart';

import 'greenfield_account_page.dart';

/// Compatibility entry retained for shell/navigation imports.
///
/// The legacy Account presentation tree has been removed. All platforms now
/// render the greenfield Account hub while business state stays in the shared
/// controller and dedicated account/wallet flows.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldAccountPage();
}

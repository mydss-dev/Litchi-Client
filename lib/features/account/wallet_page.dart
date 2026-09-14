import 'package:flutter/material.dart';

import 'greenfield_wallet_page.dart';
import 'widgets/greenfield_wallet_modals.dart';

Future<void> showWalletRechargeModal(BuildContext context) =>
    showGreenfieldWalletRechargeModal(context);

Future<void> showWalletTransferModal(BuildContext context) =>
    showGreenfieldWalletTransferModal(context);

Future<void> showWalletWithdrawModal(BuildContext context) =>
    showGreenfieldWalletWithdrawModal(context);

/// Compatibility entry retained for AppShell and Account Hub callers.
/// The legacy Wallet presentation tree has been removed; runtime rendering is
/// owned entirely by [GreenfieldWalletPage].
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) => const GreenfieldWalletPage();
}

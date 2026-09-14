# Litchi Greenfield Wallet V2

## Role
Wallet is a dedicated financial child page of Account. It must not be expanded back into the Account hub.

## Information hierarchy
1. Asset hero: total available funds, account balance, withdrawable commission.
2. Primary actions: recharge first; transfer commission and withdrawal second.
3. Quick recharge: presets plus custom amount, using the existing recharge-order and checkout flow.
4. Commission / withdrawal status: real withdraw enabled state, withdrawable amount, minimum amount and configured methods only.

## Responsive behavior
- Windows/macOS: wide asset hero, then a two-column quick-recharge and commission/status area when space allows.
- Android: touch-first vertical stack with the existing profile-child back behavior and pull-to-refresh.
- Shared theme, spacing, cards and controls remain consistent with the cross-platform framework.

## Business behavior that must not change
- submitRechargeOrder amount conversion and OrderPaymentDialog handoff.
- transferCommissionToBalance validation and refresh.
- withdrawCommission validation for enabled state, maximum, minimum, method and account.
- currency symbol and server-provided withdrawal methods.
- Account Hub public entry points: showWalletRechargeModal, showWalletTransferModal, showWalletWithdrawModal.

## Removal rule
The legacy Wallet presentation tree is not a design reference. wallet_page.dart may remain only as a compatibility/public-entry wrapper after Greenfield Wallet is wired.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android is tracked separately when the pinned libbox AAR stage blocks before Kotlin/APK compilation.

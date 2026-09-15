# Litchi Greenfield Orders V2

## Role
Orders is the purchase ledger. It should make payment state and the next available action obvious without turning every order into a large standalone card.

## Information hierarchy
1. Order state summary: pending, processing and completed/other context from the currently loaded order set.
2. Order ledger: product/top-up identity first, then date, amount, billing type, status and order number.
3. Pending-order actions: continue payment is primary; cancel is secondary/destructive.
4. Loading, error and empty states use the shared page-state components.

## Responsive behavior
- Windows/macOS: dense ledger rows that fit the default 900×700 window and preserve desktop pointer/keyboard semantics.
- Android: the same order hierarchy becomes a touch-first stacked row; it is an Account hub child and keeps back-to-Account behavior.
- The public Account Hub modal entry uses the same Greenfield order content instead of a second presentation tree.
- Platform identity and width responsiveness remain separate.

## Business behavior that must not change
- fetchOrders remains the source of the order list.
- Pending status (status == 0) is the only state that exposes pay and cancel actions.
- Continue payment uses the existing showOrderPaymentDialog and refresh callback.
- Cancel uses the existing cancelOrder API, confirmation step, success/error toast and list reload.
- Only one order action may be active at a time through the existing active trade-number guard.
- Deposit orders remain labeled as account top-up.
- Existing localized period and status mapping remain the display authority.
- showOrdersModal remains a public entry used by Account Hub.
- OrdersPage and showOrdersModal must both route to the same Greenfield ledger/state machine. Do not fork a modal-only order UI or duplicate payment/cancel behavior.

## Removal rule
The legacy per-order card composition and custom action buttons are not design references. Preserve behavior and public contracts, not the old presentation tree.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android remains separately tracked if pinned libbox AAR blocks before Kotlin/APK compilation.

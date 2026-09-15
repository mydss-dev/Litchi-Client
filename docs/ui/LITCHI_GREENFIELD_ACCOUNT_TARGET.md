# Litchi V2 — Greenfield Account Target

Legacy Account layout is not a reference design.

## Desktop

Account is an account hub with four layers:
1. Profile + current-plan hero
2. Wallet summary and financial actions
3. Account services
4. Security and preferences

The profile/plan hero is the primary focus. Wallet is secondary. Security settings must not compete visually with identity and subscription status.

## Android

Use a touch-first vertical flow:
1. avatar + identity
2. current plan + renew/purchase
3. wallet summary
4. service shortcuts
5. security/preferences
6. logout

Do not squeeze the desktop grid into a phone column.

## Business boundaries

Preserve existing behavior for:
- refreshData and updateUserSettings
- plan renewal / Shop navigation
- wallet recharge, commission transfer and withdrawal
- redemption-code API
- Telegram bind/unbind/status
- password validation/change
- logout cleanup
- panel feature flags and profile-child navigation

Wallet remains a dedicated child page. Account presentation must not use CorePlatformSupport to choose layout.

## Acceptance

- GreenfieldAccountPage is the runtime Account presentation on all platforms.
- account_page.dart is compatibility-only; legacy presentation widgets are removed.
- disabled service features are not rendered.
- desktop and Android share hierarchy, not geometry.
- test/analyze + Windows/macOS debug builds pass before moving to Wallet.

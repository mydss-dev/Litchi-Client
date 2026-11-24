# Litchi UI Design System V1.0

Status: approved design direction, incremental implementation. Do not change unrelated surfaces during a component migration.

## Component ownership

- Android mobile bottom dock: Crystal Navigation Bar (existing; do not redesign).
- Account service list: Flutter official `CupertinoListSection.insetGrouped` + `CupertinoListTile.notched`.
- Account identity and subscription cards: Forui `FCard`; avatar: `FAvatar`.
- Future general buttons, inputs, dialogs, switches: Forui, migrated only with a scoped test.
- Icons: Lucide linear icon family; do not mix icon families in new designs.
- Page routing, API, connection engine, and Windows rail: unchanged.

## Tokens (Flutter logical pixels)

| Surface | Radius |
| --- | ---: |
| Badge | 8 |
| Icon control | 12 |
| Button and field | 16 |
| Standard, identity, subscription and service card | 22 |
| Dialog and sheet top corners | 28 |
| Existing Crystal dock | 32 |

- Card fill: opaque `V3Palette.surface`; low-contrast `V3Palette.line` border.
- Modal and floating surfaces only: shadows from `V3Palette.shadows`.
- Blur restricted to the existing floating dock, not account cards or forms.
- Theme brand: `V3Palette.lychee` and `lycheeInk` for selected foregrounds.
- Existing `V3Radius` and `V3Palette` are the source of truth, not duplicated literals.
- Button and input intended touch height: 48, service rows approx. 56–60.
- Standard icons 20; dock icons 24.
- Copy, dates, account labels use existing localization helpers and user data.

## Account overview acceptance

1. Identity card: avatar, account name, email, Manage Account action.
2. Subscription card: active plan / no plan, expiry and renew/purchase.
3. Separate grouped services in this order: Wallet (when enabled or funds exist), Orders, Usage, Ticket support, Invite, Settings.
4. Keep route callbacks unchanged; hide mobile dock on secondary pages; Android system back returns to Account.
5. No changes to the Windows desktop account rail or server/connection code.
6. Test Android at 360dp and 390dp, both brightness modes, locale variants, accessibility fonts and real safe-area insets.
7. A failed CI step blocks auto-merge, including a failure pre-existing on `main`, until its cause is documented and resolved.
8. Code and automated checks are necessary but not equivalent to a human screenshot review.

## Delivery gates

- Engineer scope audit: only the agreed files/surfaces changed.
- Technical review: compile + Flutter analyze + widget tests.
- UX review: service order, labels, navigation, back, accessibility.
- Visual review: screenshots/diff for both brightness modes and primary devices.
- Cross-platform: Android and Windows build checks.
- Do not merge into `main` unless required gates are green.
- Once merged, the user reviews the integrated result and may send defects back for repair.

## Android CI toolchain compatibility

Flutter 3.50.1 requires Gradle 9.3.1 or newer; the preexisting `gradle-8.14.5` wrapper blocked Android CI before compilation.
The build engineer aligns the Android toolchain with the Flutter 3.50 template (Gradle 9.5.0, AGP 9.3.1, Kotlin 2.4.20). Existing legacy migration flags stay until all third-party plugins are audited for built-in Kotlin compatibility.

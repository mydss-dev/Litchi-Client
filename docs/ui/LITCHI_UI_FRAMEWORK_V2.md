# Litchi UI Framework V2 — Cross-Platform Frozen Target

> Status: **FOUNDATION TARGET**
>
> This document is the single source of truth for the cross-platform UI foundation. Windows, macOS and Android must share the same design language and layout tokens. Platform differences are allowed only where interaction or native window behavior requires them.

## 1. Platform Strategy

Litchi has one product identity across platforms, not three separately designed apps.

### Windows
- Desktop shell
- Persistent left navigation
- Custom window chrome where already required
- Mouse hover, focus and keyboard states

### macOS
- Same desktop information architecture and content geometry as Windows
- Keep native macOS traffic lights/title-bar behavior
- Do not fork page designs just to look "more macOS"

### Android
- Compact shell
- Bottom navigation
- Touch-first hit targets and vertical flow
- System back behavior remains Android-native
- Same colors, typography hierarchy, card language, states and brand components as desktop

Linux remains compatible with the desktop shell but is not a primary visual acceptance target for this phase.

## 2. Shared Design Direction

- 90% professional network utility
- 10% restrained Japanese / light-anime brand personality
- Clean, premium, calm, friendly
- Litchi red / sakura accent, not generic blue SaaS

Avoid full-screen anime art, cyberpunk/RGB, heavy glassmorphism, excessive gradients, emoji-heavy UI, and platform-specific visual drift.

## 3. Layout Classes

All pages classify available content width through one shared system:

- Compact: `< 600 px`
- Medium: `600–899 px`
- Expanded: `>= 900 px`

Do not add new one-off breakpoints inside feature pages unless the framework target is updated first.

## 4. Shared Geometry

### Desktop shell target (Windows + macOS)
- Default authenticated window: `900 × 700`
- Minimum: `800 × 600`
- Sidebar: `200 px`
- Main page horizontal padding: `24 px`
- Main page top padding: `20 px`
- Main page bottom padding: `24 px`

### Compact shell target (Android)
- Main horizontal padding: `16 px`
- Main top padding: `12 px`
- Main bottom content gap above navigation: `12 px`
- Respect Android safe areas
- Primary touch target: minimum `44–48 px`

### Shared
- Standard section gap: `16 px`
- Dense gap: `8 px`
- Card radius: `16 px`
- Control radius: `10–12 px`
- Pill radius: `999 px`
- Card border: `1 px`

## 5. Page Structure

Feature pages must not decide platform identity themselves when a reusable adaptive primitive can do it.

Preferred hierarchy:

`AppShell`
→ desktop or compact navigation shell
→ shared page padding / safe area
→ `AppPageScaffold`
→ feature content
→ shared components / feature widgets

Feature pages may adapt layout (row vs column, table vs cards), but colors, spacing, typography, states and component semantics remain shared.

## 6. Framework Primitives

Foundation components:

- `AppBreakpoints`
- `AppLayoutMetrics`
- `AppPageScaffold`
- `AppSpacing`
- `AppRadius`
- `AppTextStyles`
- `AppMotion`
- `AppColors` / `AppPalette`
- `AppCard`
- shared buttons, inputs, selectors, switches, modals, toast, badges

New layout magic numbers should be added to framework tokens instead of scattered through feature files.

## 7. Responsive Rules

### Desktop
- Prefer rows and split panels when width allows
- Constrain long settings/detail surfaces with max content width
- Persistent sidebar owns primary navigation

### Android
- Prefer vertical card flow
- Avoid dense desktop tables
- Bottom navigation contains only primary destinations
- Secondary/account functions live inside hub/detail navigation
- No horizontal overflow at 360 px logical width

### Medium Width
- Stack desktop split cards before reducing text below minimum readable sizes
- Preserve functional controls and state labels before decorative content

## 8. Typography

Use shared text tokens only for recurring hierarchy.

Target hierarchy:
- Page title: 24 / 700
- Section title: 16 / 700
- Body: 14 / 500
- Secondary/caption: 12
- Metric value: 22 / 800
- Metric label: 12 / 600

Use system-friendly fallback fonts. Numeric speed/traffic/latency/time should use tabular figures where possible.

## 9. Brand Tokens

- Brand Start: `#E54865`
- Brand End: `#F07C9A`
- Light app background target: `#F8F8FC`
- Dark app background target: `#0E1118`
- Dark card target: `#171D2B`

Gradients are brand emphasis, not default card backgrounds.

## 10. Platform Difference Boundary

Allowed platform-specific behavior:
- title/window chrome
- tray lifecycle
- native VPN/TUN permission flow
- system back handling
- keyboard/mouse vs touch interaction details
- safe-area handling

Not allowed without explicit design decision:
- different color systems per platform
- different typography hierarchy per platform
- unrelated card styles
- duplicated feature pages solely for visual styling
- separate business logic for UI parity

## 11. Validation Gate

Before visual redesign expands to all feature pages:

1. Framework compiles from a clean branch.
2. `flutter test` passes.
3. `flutter analyze` passes.
4. Windows shell screenshot reviewed.
5. macOS shell screenshot reviewed.
6. Android shell screenshot reviewed at a common phone width (360–412 logical px).
7. No Core/TUN/Tray/API behavior regressions.

## 12. Change Rule

When a future chat or coding session disagrees with this document:

1. Stop implementation.
2. Decide whether the target itself should change.
3. Update this document first.
4. Only then update code.

This prevents long sessions from silently drifting the design direction.

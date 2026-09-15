# Litchi UI Framework V2 — Greenfield Presentation Target

> Status: **FROZEN VISUAL TARGET**
>
> Litchi V2 is a UI rebuild. The legacy application is a source of business behavior and state contracts, not a visual template.

## 1. Non-negotiable rule

Preserve business behavior, not legacy presentation.

### Preserve
- Core / sing-box behavior
- TUN / VPN permission flow
- system proxy behavior
- tray / quit / native lifecycle
- API contracts
- auth/session behavior
- subscription, node, order and payment state transitions
- required feature capabilities and user actions

### Do not preserve merely for compatibility
- legacy widget trees
- legacy page hierarchy
- legacy card placement
- legacy spacing and density
- legacy button positions
- legacy desktop/mobile composition
- legacy colors, shadows, radii and typography

The old UI may answer **what the user must be able to do**. It must not decide **how the new UI looks or is composed**.

If a legacy page cannot reach the V2 target cleanly, replace the presentation tree instead of layering new widgets over it.

A technically compatible screen that still looks like the old product is not complete.

## 2. Product direction

- 90% professional network utility
- 10% restrained Japanese / light-anime brand personality
- clean, premium, calm, friendly
- Litchi red / sakura accent
- strong primary-state hierarchy
- deliberate whitespace
- restrained borders and shadows

Avoid generic admin-dashboard layouts, cyberpunk/RGB, heavy glassmorphism, gradients everywhere, emoji-heavy UI and legacy visual leftovers.

## 3. Platform strategy

### Windows
- desktop shell
- persistent left navigation
- custom window chrome where required
- mouse hover, focus and keyboard states

### macOS
- same information architecture and geometry as Windows
- preserve native traffic lights/title-bar behavior

### Android
- compact shell
- bottom navigation
- touch-first vertical flow
- native back behavior
- same brand, type, card and state language as desktop

Linux remains desktop-compatible but is not a primary visual acceptance target.

## 4. Layout classes

- Compact: `<600`
- Medium: `600–899`
- Expanded: `>=900`

No feature-specific ad-hoc breakpoints unless this target is changed first.

## 5. Shared geometry

### Desktop
- default authenticated window: `900×700`
- minimum: `800×600`
- sidebar: `200`
- page padding: left/right `24`, top `20`, bottom `24`

### Android
- horizontal padding: `16`
- top: `12`
- bottom content gap: `12`
- respect safe areas
- primary touch targets: minimum `48`

### Shared
- section gap: `16`
- dense gap: `8`
- card radius: `16`
- control radius: `10–12`
- pill radius: `999`
- border: `1`

## 6. New-page construction rule

For every feature page:

1. Extract required states and actions from the existing implementation.
2. Define the new information hierarchy from the V2 product goal.
3. Freeze desktop and Android composition before coding.
4. Build a new presentation tree with V2 primitives.
5. Connect existing controllers/models/services into that new view.
6. Delete or bypass legacy presentation code that is no longer needed.
7. Review actual screenshots against the new target, not against the old app.

Do not begin from the legacy widget tree and repeatedly replace individual controls while preserving its composition unless that composition already matches the frozen V2 target.

## 7. Shared primitives

Use:
- AppBreakpoints
- AppLayoutMetrics
- AppPageScaffold
- AppSpacing
- AppRadius
- AppTextStyles
- AppMotion
- AppColors / AppPalette
- AppCard
- AppButton / AppIconButton
- AppTextField
- AppSegmentedControl
- AppSwitch
- AppModal / AppBottomSheet
- AppToast
- shared loading / empty / error states

These primitives exist to implement the new design consistently. They are not a reason to keep an old page layout.

## 8. Typography

- Page title: `24 / 700`
- Section title: `16 / 700`
- Body: `14 / 500`
- Caption: `12`
- Metric value: `22 / 800`
- Metric label: `12 / 600`

Use tabular figures for speed, traffic, latency and time where practical.

## 9. Brand tokens

- Brand start: `#E54865`
- Brand end: `#F07C9A`
- Light app background: `#F8F8FC`
- Dark app background: `#0E1118`
- Dark card: `#171D2B`

Gradients are emphasis, not the default card background.

## 10. Definition of done

A redesigned page is complete only when:

1. It clearly belongs to V2 without relying on legacy composition.
2. Desktop and Android layouts are intentionally designed, not mechanically adapted.
3. Required business states/actions still work.
4. Shared components are used consistently.
5. `flutter test` passes.
6. `flutter analyze` passes.
7. Windows and macOS debug builds pass.
8. Runtime screenshots are reviewed for the target viewport.
9. No Core/TUN/Tray/API regressions are introduced.

## 11. Change rule

If a future implementation conflicts with this document:

1. stop coding;
2. decide whether the target itself changes;
3. update this document first;
4. then change code.

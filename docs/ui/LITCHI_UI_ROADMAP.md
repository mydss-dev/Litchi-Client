# Litchi UI V2 — Implementation Order

This file freezes the implementation sequence so later conversations or coding sessions do not jump ahead.

## Phase 1 — Foundation primitives (current)

- Cross-platform target document
- Shared width classes: Compact / Medium / Expanded
- Shared layout metrics
- UI platform identity abstraction
- Shell contract for Windows / macOS / Android
- Adaptive layout primitive
- Layout-aware page scaffold
- Tests for layout boundaries and platform shell contracts

**Gate:** `flutter test` + `flutter analyze` must pass.

## Phase 2 — Shell wiring

Wire the existing application shell to the framework tokens without changing business behavior.

### Windows
- Desktop sidebar shell
- Target default window 900 × 700
- Minimum 800 × 600
- Sidebar 200 px
- Shared desktop page padding
- Preserve custom window controls, tray and quit lifecycle

### macOS
- Same content geometry and sidebar as Windows
- Preserve native traffic lights and macOS quit handling
- Do not create a separate macOS feature-page design

### Android
- Bottom navigation shell
- Shared compact page padding
- Safe-area handling
- Preserve Android system-back behavior and VPN permission flow
- Minimum touch targets 48 px for primary actions

**Gate:** runtime shell screenshots from Windows, macOS and Android reviewed against `LITCHI_UI_FRAMEWORK_V2.md`.

## Phase 3 — Shared component normalization

Normalize shared UI components before redesigning feature pages:

- AppCard
- Buttons / icon buttons
- Text fields
- Selectors / segmented controls
- Switches
- Badge / chip
- Modal / bottom sheet
- Toast / tooltip
- Loading / empty / error states

No feature-specific visual redesign should bypass these primitives.

## Phase 4 — Authentication surfaces

Apply the shared system to login/register/reset flows on desktop and Android while preserving current auth window lifecycle.

## Phase 5 — Dashboard

Only after the framework and shells are accepted, implement the frozen Dashboard target.

Desktop and Android share state semantics and brand components; layout arrangement may differ by width.

## Phase 6 — Nodes

Desktop: efficient list/table presentation where appropriate.
Android: touch-first cards/list.

Keep node selection, latency and subscription logic shared.

## Phase 7 — Shop / Plans

Unify plan cards, pricing hierarchy, purchase states and billing-cycle controls across platforms.

## Phase 8 — Account / Invite / Traffic / Orders / Tickets / Settings

Migrate page by page using the accepted framework. Do not redesign all pages in one large pass.

## Mandatory rule for every phase

1. Read the framework target first.
2. Change only the current phase scope.
3. Run tests/analyze.
4. Review actual runtime UI where relevant.
5. Fix regressions before starting the next phase.

If a new idea conflicts with the frozen target, change the target document first; never silently drift implementation.

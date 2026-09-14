# Litchi Shared Components V2

This file is the source of truth for Phase 3. Change this target before changing component direction.

## Scope
Unify shared UI primitives for Windows, macOS and Android. Do not change feature business logic in this phase.

## Platform contract
- Windows/macOS: pointer-first, compact controls, hover and keyboard-focus feedback.
- Android: touch-first; primary interactive targets are at least 48 logical pixels.
- Normal controls are shared across platforms; do not duplicate feature pages by platform.

## Geometry
- Pointer regular control: 40
- Touch regular control: 48
- Pointer compact control: 34
- Touch compact control: 44
- Pointer icon button: 36
- Touch icon button: 48
- Inputs/buttons use AppRadius.md.
- Cards use AppRadius.card.
- Use AppSpacing and AppMotion; no new arbitrary spacing or motion values in shared controls.

## Required primitives
- AppButton: primary, secondary, outline, ghost, danger; disabled/loading/icon support.
- AppIconButton: adaptive target, tooltip, hover/focus/disabled support.
- AppTextField: label, hint, disabled, read-only, error/helper text, prefix/suffix, callbacks.
- AppSelect: enabled/disabled and adaptive control/menu heights.
- AppSwitch: 48x28 visual body with at least 48 touch hit height; use AppMotion.normal.
- AppSegmentedControl<T>: shared selector for ModeStrip and FilterTabs.
- AppCard remains the standard card base.
- AppBadge remains display-first.

## Migration rules
- IconActionBtn becomes a compatibility wrapper around AppIconButton.
- ModeStrip must use AppSegmentedControl and preserve Rule / Global / Direct semantics.
- FilterTabs must use AppSegmentedControl.
- AppSelector stays a state/performance primitive, not a visual component.
- Modal presentation uses AppPlatform/AppShellSpec rather than CorePlatformSupport.
- AppPageScaffold is the new width primitive; do not add new magic breakpoints.

## Acceptance gate
Every batch must pass flutter test, flutter analyze, and Windows/macOS/Android debug build checks before feature-page redesign continues.
# Litchi V3 Repository Instructions

## 1. NON-NEGOTIABLE: DO NOT REUSE OR MIX LEGACY UI
This is the first and highest-priority rule for the V3 visual reset.

- V3 UI must be designed and implemented from a blank visual layer.
- Do NOT import, wrap, restyle, extend, copy, or partially reuse legacy UI pages/widgets/surfaces from `lib/features/**` or the legacy shell in `lib/app/app_shell.dart`.
- Do NOT keep old layout structure just because it already works.
- Do NOT combine V2/Greenfield visual components with V3 components on the same screen.
- Legacy UI may only be used as a behavior reference while rebuilding equivalent behavior in V3.
- The only reusable production layers are business/state infrastructure: controllers, services, models, API/core/TUN/network logic, configuration, persistence, and localization data where appropriate.
- A V3 screen fails review if an existing user can immediately recognize the old screen structure, card arrangement, shell, or navigation skeleton.
- If reuse is uncertain, default to rebuilding the UI instead of reusing it.

## V3 Architecture Boundary

Allowed dependencies from V3:
- `lib/app/*_controller.dart` and other non-visual controller/state classes
- `lib/shared/services/**`
- `lib/shared/models/**`
- `lib/config/**`
- localization/generated strings as data
- core/platform integration

Forbidden dependencies from V3:
- legacy pages under `lib/features/**`
- legacy visual widgets under `lib/features/**/widgets/**`
- `lib/app/app_shell.dart` visual structure
- old shared presentation widgets when they preserve V2 appearance or geometry
- old Dashboard/Nodes/Settings layout code

## Visual Acceptance Standard

V3 is not accepted because it compiles. It is accepted only when:
1. Windows 900x700 looks unmistakably like a new product generation.
2. App shell/navigation, Dashboard, Nodes, and Settings have a new spatial system and visual hierarchy.
3. Light and Dark modes are both intentional, not simple palette swaps.
4. No legacy card-stack look, old sidebar composition, or old home-page silhouette survives by accident.
5. Functional behavior remains connected to the existing stable business/core layer.

## Main Branch Working Mode

V3 work now lands directly on `main` unless explicitly changed by the owner.
Do not create stacked redesign PRs or parallel UI branches by default.
Every direct-main change must still obey Rule #1 and keep the V3 boundary test green.

## Implementation Order

1. V3 shell + navigation
2. Dashboard / connection center
3. Nodes
4. Settings
5. Shop / checkout
6. Account / wallet / invite / traffic / orders / tickets
7. Legacy UI deletion after all required behavior is covered

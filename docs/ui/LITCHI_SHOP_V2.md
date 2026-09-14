# Litchi Shop V2

Phase 7 covers the Shop / Plans presentation and purchase-surface presentation only. Pricing, billing-cycle availability, order creation, payment and refresh behavior remain unchanged.

## Shared structure
- Category order remains: All / Recurring / One-time / Data pack.
- Use the shared segmented-control language for category navigation.
- Plan cards share one visual system across Windows, macOS and Android.
- Pricing is the strongest visual element, followed by plan title, plan metadata, billing cycle and features.
- Featured / popular / sold-out / low-stock states remain visible but restrained.
- Purchase actions use shared button primitives and preserve disabled/sold-out states.

## Layout
- Compact `<600`: one-column vertical plan flow, touch-first controls, pull-to-refresh preserved.
- Medium `600–899`: two-column plan grid when space permits.
- Expanded `>=900`: up to three columns using the shared layout class only; no feature-only breakpoint.
- Card gaps use the shared 16px section gap.
- No horizontal overflow at 360px logical width.

## Plan card
- Card radius follows the shared 16px card token.
- Desktop/medium cards target a consistent visual height without clipping variable plan content.
- Compact cards remain content-driven and at least 48px for every actionable control.
- Plan title and status badge share the top row.
- Price uses tabular, high-emphasis typography.
- Billing-cycle controls use shared selectable-control styling instead of feature-local gesture chips.
- Feature rows are concise and preserve backend-provided ordering.

## Purchase surfaces
- `showOrderConfirmDialog` and payment flows keep all existing business logic.
- Any visual normalization must reuse shared modal/button/input primitives.
- Do not change order amount calculation, payment methods, balance handling, coupon behavior, polling or callbacks in Phase 7.

## Platform boundary
- UI layout adapts by shared width class.
- Android keeps pull-to-refresh, safe areas and touch targets.
- Windows/macOS keep pointer hover/focus behavior through shared controls.
- Do not use `CorePlatformSupport` to choose Shop visuals.

## Gate
- `flutter test`
- `flutter analyze`
- Windows debug build
- macOS debug build
- Android UI build is observed separately because the existing pinned `libbox.aar` build step may block before Flutter compilation.

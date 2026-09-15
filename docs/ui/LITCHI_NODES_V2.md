# Litchi Nodes V2

Phase 6 covers `NodesPage` and `showNodePicker` presentation only.

## Desktop
- Search + node count + 40px latency action in one control row.
- Search uses the shared pointer geometry (40px regular height).
- Auto Select remains the first selectable row.
- Shared horizontally scrollable filter strip.
- Node list uses one bordered surface and owns its scrolling.
- Manual node rows target 58–60px height.
- Selected row uses a 3px brand accent, soft brand background, and brand-colored title.
- Row order: flag, name, secondary label, latency, favorite action, selected state.
- Latency and favorite actions use the shared button primitives, including shared loading state.

## Android
- Keep the existing compact header/back structure.
- Search + 48px latency action.
- Search uses the shared touch geometry (48px regular height).
- Auto Select card at least 68px high.
- Filters stay horizontally scrollable.
- Manual node cards are at least 72px high and favorite interaction is touch-safe.
- Pull-to-refresh remains available.

## Picker
- Desktop modal max width: 720px.
- Desktop picker uses the shared 40px search/button geometry and 60px selectable surfaces.
- Android keeps the bottom-sheet form with keyboard inset, drag handle and safe area.
- Android picker actions use 48px shared icon-button targets and 72px selectable surfaces.
- Search, filters, latency action and close action reuse shared controls.
- Picker selected surfaces use the same soft brand background, brand border/title and selected indicator as the Nodes page.

## Rules
- UI platform choice comes from `AppPlatform` / `AppShellSpec`.
- Keep node selection, favorites, latency testing, search and filters behavior unchanged.
- Reuse shared controls and shared spacing/radius/motion tokens.
- Do not redesign unrelated pages in this phase.

## Gate
`flutter test`, `flutter analyze`, Windows debug build and macOS debug build.

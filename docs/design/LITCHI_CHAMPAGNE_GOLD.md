# Litchi Client · Champagne Gold UI (2026-11-26)

> **Status:** approved direction; staged implementation. The source of truth for
> pixel comparison is the user-provided `litchi-design-spec (1).zip` (HTML +
> 20 screenshots: seven core screens in both modes plus three extra connection
> status variants in both modes). These reference PNGs are **not**
> included in this commit. Visual reviewers must obtain the original archive
> before claiming fidelity. The values below are the implementation contract.

## Style
Charcoal + champagne gold + restrained glass. No neon, glowing text gradient,
3D illustrations or opaque wireframe card borders. Gold is only for primary
actions and selection. Green is exclusively for connected/healthy states.

| Token | Dark | Light |
|---|---|---|
| canvas | #0A0D0F | #F2F0EB |
| canvasDeep | #050808 | #E5E0D9 |
| surface | white @6% | white @75% |
| surfaceStrong | white @10% | white @96% |
| surfaceSolid | #14171A | #FCFCFA |
| ink | #F5F2ED | #17171A |
| ink2 | #A3A3A6 | #5C5E63 |
| ink3 | #6E7075 | #919499 |
| line | white @10% | #17171A @10% |
| lineStrong | white @20% | #17171A @16% |
| glassBorder | white @18% | white @85% |
| gold | #E8C269 | #A88033 |
| goldTint | #E8C269 @14% | #F5EDD6 |
| orbFace | #E8C269 | #171C21 |
| onGold | #14120D | #FFFFFF |
| aqua | #9ED9D6 | #29807D |
| success | #7DD9A6 | #178759 |
| danger | #E07866 | #BF422B |

`warning` remains a separate amber role for neutral alerts, never the same
token as gold. Legacy fields retain aliases during migration. Do not replace
existing V3Palette fields with null or delete semantic names.

Typography: Chinese Noto Sans SC and numeric/Latin Geist **after assets are
legally sourced and bundled**, with platform fallbacks until then. Never mix
dynamic numeric values and Chinese characters in the same Text widget.
Page title 22/600; card title 17/600; large number 40/500 (-1.2 tracking);
balance/price 32/600 (-1); duration 28/500 (-.5); metric 15/500; small
value 11/500; primary row 14/500; body 12/400; field 11/400; navigation
label 10/600.

Geometry: radii 8/18/21/24/30/999; spacing tokens 4/6/8/10/14/18/24;
20dp horizontal gutter, responsive content (never fixed 372dp screen width);
native SafeArea (do not hardcode 62dp status bar). Component glass uses
BackdropFilter sigma 28, translucent surface, 1px inner highlight, shadow
normal 0 8 24 -8 @16%; hero 0 14 36 -10 @20%; nav 0 12 32 -10 @22%.
Deterministic monochrome film grain ~12% above backdrop and below content;
pointer-transparent and never blocking gestures.

## Page structure (7 screen designs, 14 mode references)

1. **Connect:** header; layered glass Stack main control with 140dp
   orbFace circle, concentric rings, active node, status, duration and live
   rates; current-node card; 3 metrics; subscription quota; existing four-tab
   floating nav. Preserve all existing connect/disconnect/error/loading
   states and business actions. The newer design intentionally uses a
   circular main orb, overriding the prior temporary mobile pill.
   **Updated 2026-11-26 status images (new 01B section):**
   - **Disconnected:** translucent glass button with a gold outline, gray
     protection badge, 00:00:00 timer and "Tap to connect".
   - **Connecting:** opaque gold (dark) or charcoal (light) button, busy
     indicator and "Connecting" label. Disconnecting also reads as busy.
   - **Connected:** solid face, green protection badge, real duration, real
     up/down/session values; the circular button's tap disconnects.
   - **Error:** translucent glass face with a danger-colored outline,
     "Connection failed" and a retry action. Do not claim a specific cause
     that the backend has not diagnosed.
   - **Hard rule:** if status is NOT Connected, render 0 B/s for upload and
     download and 0 MB for *this-session* usage regardless of any stale
     ValueNotifier counters. Subscription lifetime usage/quota is **not**
     a session counter and must still show real account data.
   - Layout geometry and button action must remain stable across variants.

2. **Nodes:** header, search, segment, region-grouped node rows,
   latency and selection status. **Do not add favorites** (previous
   user decision), and do not add unsupported streaming flags. Untested =
   outline lightning; testing = spinner; result = region-aware latency
   capsule; timeout is separate. Keep real filtering and benchmarks.
3. **Traffic:** month selector, total + seven-day chart with today
   highlighted, up/down comparison, recent entries. No fake usage samples.
4. **Plans:** cycle segment, current plan, recommended plan, base plan,
   payment notes. One-time/recurring behavior and checkout remain unchanged.
5. **Wallet:** real balance/currency, recharge, shortcuts, gift-card,
   actual transaction history. Wallet is a secondary account page, so
   retain the back affordance.
6. **Account:** account identity, plan badge, subscription, invite,
   existing service links. Preserve all real destinations.
7. **Settings:** routing rules, existing connection preferences,
   general settings and About, retaining current persisted state.

Root navigation remains **Connect / Nodes / Plans / Account**. Secondary
Wallet, Traffic, Settings and other screens get a visible back action
rather than a duplicate four-tab navigation bar. No fake feature controls.

## Implementation + review order

1. ThemeExtension + existing ThemeData attachment + empty-page light/dark
   smoke test; common glass/backdrop components.
2. Shell widgets (status-bar/SafeArea integration and existing four-tab dock).
3. In parallel after foundation API stabilizes: Connect+Nodes, Traffic+Plans,
   Wallet+Account+Settings. One engineer owns each file and one PR.
4. Independent auditor checks source diffs, light/dark screenshots, 320/360/
   390/430dp, Windows, touch targets >=44dp, true locale data, empty/error
   and loading states, performance and WCAG contrast, plus Flutter
   analyze/test and build. **No merge until audit and final user review.**

Implementation tasks: #133 / #134 / #135 / #136; independent audit: #137.

## Revised archive delta

The updated ZIP adds six 824×1784 status images and an HTML `01B`
section: `3_1` / `3_114` / `3_227` (dark disconnected,
connecting, failed) and `3_340` / `3_453` / `3_566`
(light versions). All fourteen earlier page images are unchanged, and
the page list, theme colors, type scale and navigation contract are unchanged.
The existing HTML cover counts ten pairs (seven screens plus three extra
states), not ten new navigation pages.

Open issue #134 and its child PR for implementation; #137 independently
reviews the three new states in both themes as well as connected and
disconnecting behavior.


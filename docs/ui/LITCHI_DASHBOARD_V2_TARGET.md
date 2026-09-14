# Litchi Dashboard V2 — Frozen Design Target

> Status: **FROZEN TARGET**
>
> This document is the single source of truth for the Litchi desktop dashboard redesign. Do not change UI direction from chat context, ad-hoc taste, or implementation convenience. If a target needs to change, update this document first, then change code.

## 1. Product Direction

Litchi is a professional network/proxy client with a restrained Japanese/anime brand layer.

Target character:

- 90% modern professional network utility
- 10% light anime / Japanese digital-product personality
- Clean, premium, calm, friendly
- Recognizable as Litchi even without the logo

Avoid:

- generic Material/SaaS blue dashboards
- full-screen anime artwork
- cyberpunk / RGB / neon-heavy visuals
- excessive glassmorphism
- gradients on every card
- oversized rounded corners everywhere
- emoji-heavy UI
- game-launcher styling

## 2. North-Star Visual Structure

The desktop home hierarchy is fixed as:

1. Notice banner
2. Connection + Network hero row
3. Realtime metrics
4. Subscription / traffic card

The page must answer within one glance:

1. Am I connected?
2. Which node am I using?
3. Which network/proxy mode is active?
4. What are my upload/download speeds?
5. How long have I been connected?
6. How much traffic is left and when does the plan expire?

## 3. Desktop Geometry

Target shell values:

- Default window: `900 × 700` target
- Minimum window: `800 × 600`
- Sidebar: `200 px` target
- Main horizontal padding: `24 px`
- Main top padding: `20 px`
- Main bottom padding: `24 px`
- Standard section gap: `16 px`
- Standard card radius: `16 px`
- Card border: `1 px`

Important: shell dimensions may be implemented in a later shell-only phase. Do not touch tray/native/core lifecycle just to gain a few pixels.

## 4. Hero Row

At non-compact desktop width:

- Connection card: `56%`
- Network card: `44%`
- Gap: `16 px`
- Both cards: exactly `228 px` high

At compact width:

- stack vertically
- preserve `16 px` gap
- no horizontal overflow

### 4.1 Connection Card

Required information:

- connection state
- connection duration when connected
- short connection-method description
- branded connection orb
- current node
- country flag
- node secondary name / selection mode
- latency
- entire node row is clickable

State colors:

- Connected: Litchi brand color
- Connecting: Litchi brand color
- Disconnecting: muted
- Error: danger
- Disconnected: muted

The card must not directly own connection/core logic.

### 4.2 Litchi Connection Orb

This is the primary Litchi brand interaction.

Target size: `136 px`

It must support:

- disconnected
- connecting
- connected
- disconnecting
- error

Visual language:

- circular/fruit-core abstraction inspired by lychee
- connected state uses Litchi red → sakura pink gradient
- restrained glow only when appropriate
- subtle inner/outer signal rings
- no generic large Material power button appearance
- central power/retry icon may remain as a functional affordance

Motion:

- breathing only during transition state
- small amplitude only
- respect reduced-motion / disabled animations
- no bounce/elastic animation
- no permanent high-cost animation

Interaction remains delegated to the existing controller callback.

## 5. Network Control Card

Height: `228 px`

Must contain:

- title: network settings
- connection method selector: System Proxy / TUN
- proxy mode selector: Rule / Global / Direct

Controls must use consistent segmented-control language.

Do not replace real TUN permission/conflict logic with visual-only switches.

## 6. Realtime Metrics

Card height: `104 px`

Three equal columns in this order:

1. Download
2. Upload
3. Connection duration

Each metric:

- icon tile: about `36 × 36 px`
- label: `12 px`, medium/semibold
- value: `22 px`, bold
- use tabular figures for numbers where supported

Performance rule:

- download listens only to download notifier
- upload listens only to upload notifier
- duration listens only to the 1-second uptime ticker
- do not rebuild the whole dashboard every second

## 7. Subscription / Traffic Card

Target height: `154 px`

Required layout:

Top row:

- plan icon
- current plan name
- optional premium badge only when semantically valid

Middle:

- `8 px` high progress track
- Litchi gradient progress fill
- used / total traffic text

Bottom: three equal metrics

1. Remaining traffic
2. Today used
3. Expiry date

Priority:

`remaining > used > total`

Do not use circular gauges.

## 8. Brand Color Tokens

Current target values:

### Brand

- Brand Start: `#E54865`
- Brand End: `#F07C9A`

### Light

- App Background: `#F8F8FC`
- Card: `#FFFFFF`
- Muted Surface: `#F4F2F6`
- Border: `#E7E2E8`
- Soft Border: `#F0ECF1`
- Primary Soft: `#FFEDF1`
- Secondary Soft: `#FFF0F5`

### Dark

- App Background: `#0E1118`
- Card: `#171D2B`
- Muted Surface: `#202737`
- Border: `#30394B`
- Soft Border: `#242D3D`
- Primary Soft: `rgba(229,72,101,0.16)`
- Secondary Soft: `rgba(240,124,154,0.16)`

Rules:

- cards are normally solid surfaces, not gradients
- gradient is reserved for brand emphasis such as the connection orb and progress accents
- semantic success/warning/danger colors remain semantic

## 9. Typography

Use shared typography tokens rather than page-specific random font sizes.

Dashboard target tokens:

- Hero status: `18 px / 800`
- Section title: `16 px / 700`
- Metric value: `22 px / 800`
- Metric label: `12 px / 600`
- Plan value: `18 px / 800`
- Body: `14 px`
- Caption: `12 px`

Font fallback stays platform-friendly:

- Inter
- SF Pro
- Segoe UI
- HarmonyOS Sans SC
- Microsoft YaHei
- PingFang SC

Do not add a large bundled font asset in this phase.

## 10. Spacing and Radius

Use the existing 4px-based spacing scale:

- 4
- 8
- 12
- 16
- 20
- 24
- 32
- 40
- 48

Avoid arbitrary values unless technically necessary.

Primary radius levels:

- compact: 8–10
- card: 16
- large/hero: 18 only when clearly justified
- pill: 999

## 11. Anime / Mascot Layer

Mascot is **not required for Dashboard V2 core implementation**.

Future target:

- small Litchi mascot in selected emotional states
- login / empty state / connection success / no-plan / error are valid placements
- mascot should never dominate the dashboard
- no anime wallpaper behind functional content

The mascot is a brand layer, not navigation or business UI.

## 12. Interaction and Accessibility

Desktop requirements:

- hover for clickable controls
- visible but restrained keyboard focus
- tooltip for icon-only actions
- pointer cursor on clickable elements
- semantic labels on primary controls
- reduced-motion respected
- light and dark themes both valid

## 13. Architecture Guardrails

Dashboard redesign MUST NOT change behavior of:

- sing-box core communication
- CoreController connection flow
- TUN permission logic
- system proxy implementation
- kill switch
- tray lifecycle
- window quit lifecycle
- native method channels
- auto-login/token logic
- subscription API semantics
- node parsing/protocol support

UI components receive state and callbacks; business controllers remain the source of truth.

## 14. Responsive Guardrails

Use shared breakpoints.

Current target:

- compact: `< 600`
- medium: `600–899`
- expanded: `>= 900`

Do not introduce new one-off breakpoints inside Dashboard without updating the design system first.

## 15. Definition of Done — Dashboard V2

Dashboard V2 is not considered done until all are true:

- visual hierarchy matches this document
- connection/network cards align and share height
- orb is visually dominant but not oversized
- realtime metrics are three-column and independently updating
- traffic card has progress bar and three summary metrics
- dark mode feels intentional, not inverted light mode
- light mode remains usable and balanced
- no business behavior regression
- `flutter test` passes
- `flutter analyze` passes
- no newly introduced ignores to hide analyzer failures
- Windows runtime screenshot is reviewed against this target

## 16. Change-Control Rule

This rule is mandatory for future work:

1. Read this file before modifying Dashboard UI.
2. State which target section the change implements.
3. If a proposed change conflicts with this document, do **not** silently change code.
4. Update this document first and explicitly record the new target.
5. Only then change implementation.

Chat history is advisory. **This file is authoritative.**

## 17. Current Implementation Status

Phase 5 clean-stack baseline:

- branch starts from the accepted Auth V2 head
- brand red/pink palette: implemented
- dark navy-black palette: implemented
- shared spacing/motion/breakpoints/components: implemented
- connection orb: existing but requires V2 size/visual review
- hero row 56/44 and 228px: pending
- realtime three-column card: pending
- traffic progress card: pending
- mascot: deferred
- shell 200px / 900×700 target: keep existing shared shell metrics unless a dashboard-only change genuinely requires otherwise
- CI: must be green before Phase 5 is marked complete

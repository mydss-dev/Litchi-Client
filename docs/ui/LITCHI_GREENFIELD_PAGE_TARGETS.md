# Litchi V2 — Greenfield Primary Page Targets

> These targets describe the final presentation. Legacy layouts are not reference designs.

## 1. Dashboard — final target

### Desktop 900×700

Content area is approximately 652 px wide after the 200 px sidebar and page padding.

Vertical composition:

1. Notice strip — 40–44 px
2. Connection workspace — 238–250 px
3. Realtime metrics — 92–104 px
4. Subscription block — remaining primary content

### Connection workspace

Use **one dominant full-width surface**, not two legacy cards placed side by side.

Internal desktop composition:
- left: 136 px Litchi connection core / power interaction
- center: connection state, elapsed time, selected node, latency
- right: network mode (`Rule / Global / Direct`), route summary and node-change action

The connection core is the visual anchor. The rest of the page must not compete with it.

Disconnected state:
- calm neutral surface
- primary call to action is connecting
- node and mode remain visible

Connecting/disconnecting:
- subtle pulse only
- no aggressive RGB or spinning decoration

Connected state:
- Litchi red/sakura emphasis
- current node and connection duration become secondary confirmation

### Realtime metrics

One compact surface with three equal metrics:
- download
- upload
- connection duration

Values use tabular figures. No extra mini cards inside.

### Subscription

One coherent block:
- plan name
- traffic progress bar
- remaining traffic
- today used
- expiry

Do not scatter subscription information across multiple unrelated cards.

### Android

Order:
1. notice
2. connection core + status
3. current node / change node
4. mode selector
5. realtime metrics
6. subscription

The desktop connection workspace becomes a purposeful vertical composition, not a squeezed horizontal card.

---

## 2. Nodes — final target

### Desktop

Nodes is a **node browser**, not a settings list.

Composition:
- top toolbar: title + search + latency test
- below: two-pane browser
  - left rail: All / Favorites / regions
  - right pane: Auto Select pinned first, then node rows

Node row target: 60–64 px.

Each row prioritizes:
1. node name
2. region / transport metadata
3. latency
4. selected state
5. favorite action

Selected node uses a restrained brand surface + left accent, not a heavy filled red card.

Auto Select is visually distinct from physical nodes and always remains easy to return to.

Filtering must never hide the currently selected state without explanation.

### Android

Composition:
- title + test action
- search field
- horizontally scrollable region chips
- Auto Select card
- node cards, minimum 72 px

Node cards show only essential metadata. Secondary protocol details may move to a subtle second line.

No desktop-style table compression.

### Quick node picker

The node picker is a **quick switcher**, not a miniature copy of the full Nodes page.

Desktop:
- command-palette style centered surface, target max width around 660–680 px
- search + latency test in the first control row
- horizontally scrollable region filters
- Auto Select pinned first
- node rows reuse the same visual language as the full node browser
- no Favorites rail and no desktop two-pane navigation inside the picker

Android:
- adaptive bottom sheet, target max height around 90–92% of the viewport
- search + compact latency test action
- horizontal region chips
- Auto Select first, then touch-first node rows

If the active filter hides the current manual node, keep that current selection visible as a pinned row instead of silently removing it.

---

## 3. Shop / Plans — final target

Shop is a product-selection page, not a settings form.

### Desktop

Composition:
1. page heading / short value statement
2. current-plan status strip if the account has an active plan
3. category selector
4. plan grid

At the default 900×700 desktop window, use **2 columns**. Do not force 3 narrow cards into the 652 px content area.

Expanded content widths may use 3 columns when cards stay at least ~260 px wide.

### Plan card

Visual hierarchy:
1. plan name / tier
2. traffic quota as the hero value
3. price + billing unit
4. 3–5 concise benefits / limits
5. purchase CTA

A featured plan may use a restrained brand border or top accent. Do not make every plan card equally loud.

Billing-cycle selection belongs either in a clean global selector when it applies consistently or in the order flow. Do not create dense control clusters inside every card.

Implementation lock:
- the default 900×700 desktop composition must resolve to **2 plan columns**
- a plan card must **not contain its own billing-cycle segmented control**
- recurring billing periods are selected in order confirmation, where every available backend period remains visible
- traffic quota is the hero value; price is secondary

### Order confirmation

One clear purchase summary:
- plan
- selected billing cycle
- original price / discount / total
- coupon input
- primary submit action

Warnings about switching an active plan must be visible before submission but should not dominate the dialog.

Implementation lock:
- pricing, coupon verification, period mapping and order submission stay outside the presentation surface
- the presentation surface receives already-derived values and callbacks only
- selecting a billing period may reset an applied coupon exactly as the existing business flow does
- there is one obvious primary submit action; cancel is visually secondary

### Payment

Desktop: centered payment surface.
Android: bottom sheet / full-height compact flow as needed.

Stages remain:
- payment method
- QR / external payment
- success
- expired

The UI may be rebuilt completely, but the existing payment state machine and calculations remain untouched.

Implementation lock:
- each payment stage has one obvious primary task/action
- presentation code must not call payment APIs or calculate prices/fees
- checkoutOrder, handling-fee math, balance/surplus/refund adjustments, 15-minute countdown and 3-second polling remain in the state/controller layer
- QR/browser presentation only receives the final payment URL, amount, countdown and callbacks
- success and expired stages must not preserve legacy method-selection clutter

---

## 4. Visual consistency rules

- Do not nest cards inside cards unless the nested surface has a clear semantic reason.
- One page should have one obvious primary visual focus.
- Use brand red/sakura for active/primary state, not as constant decoration.
- Prefer whitespace and hierarchy over more borders.
- Avoid preserving an old element solely because removing it requires more presentation code changes.
- Desktop hover/focus and Android touch states are required.
- Dark and light mode must share the same hierarchy.

## 5. Acceptance

A primary page is accepted only after:
- actual Windows screenshot at 900×700
- Android screenshot at 360–412 logical px
- dark/light sanity check
- no clipped text or horizontal overflow
- primary action/state is visually obvious within one glance
- business state/actions remain wired

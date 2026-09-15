# Litchi UI V2 — Greenfield Implementation Order

This roadmap freezes the new rule: preserve business contracts, rebuild presentation.

## Phase A — Foundation
Already established:
- shared layout classes
- shared metrics
- cross-platform shell contract
- shared controls
- auth/business wiring
- existing service/controller integrations

These are implementation assets, not final visual layouts.

## Phase B — Final visual rebuild of primary surfaces

### Dashboard
- define final desktop and Android composition first
- replace legacy presentation tree where needed
- connection state is the primary visual focus
- network mode is secondary but immediately accessible
- realtime metrics are compact and readable
- subscription information is one clear block
- no legacy card arrangement preserved for compatibility

### Nodes
- desktop: purpose-built node browser, not a legacy list with new buttons
- Android: touch-first node browser, not a shrunk desktop table
- selection, latency, favorites, filters and auto-select behavior remain wired to current logic

### Shop / Plans
- redesign product browsing and purchase hierarchy from scratch
- pricing and plan differences must be visually obvious before interaction
- order confirmation and payment use the new visual language
- order/payment calculations and state machine remain unchanged

**Gate for each page:** target spec → implementation → test/analyze → Win/mac build → actual screenshot review.

## Phase C — Remaining surfaces

Rebuild one surface at a time:
- Account
- Invite
- Traffic
- Orders
- Tickets
- Settings

For every surface:
1. extract required capabilities;
2. ignore legacy composition;
3. define new desktop + Android target;
4. build new presentation tree;
5. connect existing business logic;
6. remove obsolete presentation code;
7. review actual screenshots.

## Mandatory rules

- Do not call a page complete just because old functionality still works.
- Do not preserve layout merely to minimize code changes.
- Do not mix legacy and V2 visual systems on the same page.
- Shared components support the target; they do not define the target.
- Business/native compatibility is required. Visual compatibility with the old client is not.
- When the target is unclear, freeze the target before coding.

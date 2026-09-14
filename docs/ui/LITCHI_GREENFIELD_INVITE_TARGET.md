# Litchi Greenfield Invite V2

## Role
Invite is the referral growth page. The invite code/link is the primary object; referral statistics and commission history support it.

## Information hierarchy
1. Invite hero: active invite code, active share link and code position when multiple codes exist.
2. Primary actions: copy link and create invite code.
3. Share actions: WeChat, QQ, Twitter and Telegram preserve the current clipboard-first behavior.
4. Referral statistics: registered users, pending commission, total commission and commission rate.
5. Commission records: recent server-provided referral records only.

## Responsive behavior
- Windows/macOS: invite hero and statistics use the available width; records remain a clear secondary section.
- Android: one vertical touch-first flow with pull-to-refresh.
- Platform identity and width responsiveness are separate: Windows/macOS must not switch to Android presentation merely because the content width is narrow.
- Width may reduce statistics from four columns to two, but touch-only title/action behavior remains touch-only.
- If Invite is reached as a profile child, preserve the Account back path; as the normal compact primary tab it has no extra back header.
- One adaptive presentation tree replaces separate desktop and compact widget trees.

## Business behavior that must not change
- InviteController remains the authority for link normalization and fallback link generation.
- Existing inviteCodes / inviteCode / inviteLink fallback behavior remains intact.
- createInviteCode keeps the existing controller/API call and refresh.
- Copy validates a non-empty link, writes to Clipboard and shows the existing success/warning toast.
- Share keeps the existing clipboard-first behavior and target-specific toast; do not invent native share APIs.
- invitedCount, pendingCommission, earnedCommission, commissionRate and inviteRecords remain controller-owned.
- Pull-to-refresh uses refreshData.

## Removal rule
The legacy Invite desktop/compact presentation split is not a design reference. invite_page.dart may remain only as a compatibility entry after Greenfield Invite is wired.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android remains separately tracked if pinned libbox AAR blocks before Kotlin/APK compilation.

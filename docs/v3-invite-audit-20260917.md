# V3 invitation-page audit (part 5 of #81)

Scope: independent of draft PRs #82–#85. Preserve backend fields and existing copy/creation operations; do not invent referral metrics or commission rules.

Source-confirmed problems in `v3_invite_page.dart`:
- The hero treats a link-only record as having a code and prints the made-up string `LITCHI`.
- Either copy action stays enabled even when its respective value is empty; tapping it only produces an error snackbar.
- Creating a code retains the old selection even after a new item appears, so users may think creation had no effect.
- `invitedCount` is labelled `成功邀请` even though the backend count is invited/registered users rather than verified paid conversions; invitation order/commission records are labelled generically as invitation records.

Acceptance: truthful missing-code/link states; independent disabled copy actions; selected code retained across refresh/reordering and newly created code revealed when returned; API errors shown without reporting success; distinguish invited count from order/commission records; 390px/900px and light/dark regressions. Design keeps code/link actions first, real stats second, historical records last. Share is copy-only until a native share integration exists.

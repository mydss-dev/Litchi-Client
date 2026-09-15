# Litchi Greenfield Traffic V2

## Role
Traffic is the usage-intelligence page. It should answer three questions quickly: how much quota remains, what changed today, and when the subscription/reset cycle changes next.

## Information hierarchy
1. Quota hero: remaining traffic is the primary number; used/total and progress support it.
2. Today status: today's usage plus the existing yesterday comparison.
3. Subscription cycle: expiry / remaining days and monthly reset countdown.
4. Usage trend: existing 7 / 30 / 90 day data with upload, download and total tooltip details.
5. No-plan state: preserve the existing purchase path when Shop is enabled.

## Responsive behavior
- Windows/macOS: keep desktop identity at the default 900×700 window. Use a wide quota hero with supporting cycle/status information, followed by a full-width trend section.
- Android: one touch-first vertical flow under the shared compact header.
- Platform identity and width responsiveness are separate. A narrow desktop content area must not become the Android presentation.
- Width may stack supporting status blocks, but desktop title/interaction semantics remain desktop.

## Business/data behavior that must not change
- AppController remains the source of traffic, todayTrafficGb, trafficUsage, dailyUsage, expiredAt, resetDay and hasPlan.
- refreshData remains the refresh action.
- subscriptionExpiryDisplay / validResetDay / daysUntilMonthlyReset / yesterdayComparisonText remain the shared calculation authorities.
- The trend selector remains 7 / 30 / 90 days.
- Existing calendar-day fill behavior and upload/download tooltip values remain intact.
- No new traffic API or derived billing rule is introduced.

## Presentation rule
- The legacy desktop metric grid and compact stat-card tree are not design references. Reuse data/calculation logic, not the old card composition.
- Brand colors remain runtime-configurable through AppPalette/AppConfig. Traffic charts must consume the runtime brand getters rather than hard-code or const-fold the brand gradient.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android remains separately tracked if pinned libbox AAR blocks before Kotlin/APK compilation.

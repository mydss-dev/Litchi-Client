# Litchi Greenfield Tickets V2

## Role
Tickets is the support inbox. The page should make active conversations, ticket state and the next support action easy to scan without turning every ticket into an isolated generic card.

## Information hierarchy
1. Support summary: open conversations, closed conversations and total ticket context from the loaded list.
2. Support inbox: subject first, then priority, date and open/closed state.
3. Primary action: create a new ticket.
4. Conversation modal: message thread first, then reply / close controls when the ticket is open.
5. Loading, error and empty states use shared page-state components.

## Responsive behavior
- Windows/macOS: one continuous inbox surface with dense pointer-oriented rows sized for the default 900×700 window.
- Android: the same hierarchy becomes a touch-first stacked row; Tickets remains an Account hub child with back-to-Account behavior.
- New-ticket and conversation flows reuse the shared adaptive modal system rather than creating separate desktop/mobile dialog trees.
- Platform identity and width responsiveness remain separate.

## Business behavior that must not change
- getTickets remains the list source and refresh action reloads that source.
- createTicket keeps the existing subject/message validation: required fields, subject length >= 5 and message length >= 10.
- Before createTicket, getUserInfo and getSubscribeInfo remain best-effort preflight requests used only to distinguish the backend subscription-mismatch error.
- ticketBestEffort, isTicketSubscriptionRequiredError and ticketAccountHasActiveSubscription remain the compatibility authorities for that mismatch handling.
- getTicketDetail remains the conversation-detail source when a ticket is opened.
- replyTicket requires a non-empty reply, reloads detail after success and refreshes the inbox through the existing callback.
- closeTicket keeps the existing close call, modal dismissal, success/error toast and inbox refresh callback.
- Ticket priority mapping (0/1/2) and open/closed status mapping remain unchanged.
- Message ownership remains driven by TicketMessageModel.isAdmin.

## Presentation rule
The legacy one-card-per-ticket list, raw FilledButton/OutlinedButton actions and hand-built priority selector are not design references. Preserve support semantics and API behavior; rebuild presentation with shared Greenfield components.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android remains separately tracked if pinned libbox AAR blocks before Kotlin/APK compilation.

# Phase 7 — redemption localization and truthful success states

Source review of `lib/v3/pages/v3_gift_card_page.dart` on main `0fdbcc6f`: its copy promised every code credits wallet balance, but the existing localization resource describes balance, traffic, duration and plan benefits. The UI also set a successful redemption message before `refreshData()` and then caught refresh errors as if redemption itself failed, encouraging attempts to re-use a potentially single-use code.

Changes are deliberately limited to this redemption form. Use existing generated ARB keys for common labels; source-language-specific explanatory text is explicitly translated into English, Simplified and Traditional Chinese. Never invent an entitlement until the panel confirms it. An API failure keeps the code and shows a localized error; confirmed redemption clears the code and remains a success even if refreshing account data fails. Do not retry a confirmed code on refresh failure. The sheet title now follows the locale.

Acceptance: English input validation; backend error without success/clearing; successful redemption followed by failed refresh without duplicate API call; simplified/traditional wording; 360dp light/dark widget smoke, CI and screenshot checks. Other V3 pages still require separate localization. Independent of draft #82–#87; do not merge before checks and visual review.

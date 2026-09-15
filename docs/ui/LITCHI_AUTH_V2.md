# Litchi Auth V2

Implementation status: Auth V2 implementation is code-complete for this phase and is waiting on the acceptance gate. Keep this target frozen until the gate is green.

This file is the source of truth for Phase 4. Change this target before changing auth visual direction.

## Scope
Unify the authentication experience for Windows, macOS and Android without changing login, registration, credential storage, token, invite-code, verification-code or API behavior.

## Desktop target (Windows + macOS)
- Fixed auth window width: 860 logical px.
- Login height: 620.
- Register height: 760.
- Change-password height: 660.
- Forgot-password height: 720.
- Two-column auth shell: brand surface 42%, form surface 58%.
- Form content max width: 420.
- Outer gap/padding follows AppSpacing; no new arbitrary breakpoints.
- macOS keeps native traffic lights; Windows keeps existing custom window chrome.

## Android target
- Single-column auth flow.
- Compact brand visual above the form.
- Use SafeArea and scroll when the keyboard or short viewport requires it.
- Controls use the shared touch contract: normal target >= 48 logical px.
- No separate Android-only copy of the login/register forms.

## Visual language
- Litchi Neo Anime: 90% professional network utility, 10% Japanese/anime brand accent.
- Use semantic AppColors and the existing Litchi red/sakura gradient.
- Brand area uses logo + abstract Litchi Core / network motif first; no large anime character background in this phase.
- Cards use AppRadius.card; controls use AppRadius.md.
- Motion uses AppMotion and respects reduced-motion settings.
- Light and dark modes must both be first-class.

## Component rules
- AuthInput is a compatibility wrapper around AppTextField.
- AuthPrimaryButton wraps AppButton.
- Auth links/checkboxes use shared motion, spacing and adaptive hit geometry.
- Register send-code control uses AppButton.
- Keep complex email-suffix behavior intact; only normalize its geometry and visuals.
- AuthFlow must use AppPlatform/AppShellSpec/AppLayoutMetrics, never direct dart:io platform checks for presentation.

## Business behavior that must not change
- CredentialsStorage behavior and remember-credentials flow.
- JWT cleanup behavior for legacy saved passwords.
- loginWithCredentials/registerWithCredentials APIs.
- startup warning toast behavior.
- registerOpen, email verification, suffix list, invite-code and terms validation.
- auth screen routing.

## Acceptance gate
- flutter test passes.
- flutter analyze passes.
- Windows debug build passes.
- macOS debug build passes.
- Android Flutter UI remains shared; Android full APK remains separately blocked only if the pinned sing-box libbox AAR build fails.
- No Core/TUN/system-proxy/tray/API behavior changes.

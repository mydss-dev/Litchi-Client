# Litchi Greenfield Settings V2

## Role
Settings is the control center for app behavior, connection behavior, diagnostics and version information. It should feel precise and calm, with platform-specific capabilities shown only where they are actually supported.

## Information hierarchy
1. System: launch-at-startup, silent startup, automatic updates, appearance and language.
2. Connection: available network interception mode and DNS selection.
3. Advanced: connection protection / kill switch, network repair and diagnostics.
4. About: app version and sing-box core version.
5. Security warning: surface the existing non-HTTPS warning before normal settings when the configured server is insecure.

## Responsive behavior
- One adaptive Settings presentation tree is used for Windows, macOS and Android.
- The default 900×700 desktop window stays a readable single-column settings flow inside the shared content width; do not force a cramped two-column grid at ~650px content width.
- Wider desktop content may expand groups into two columns when each card still has comfortable control width.
- Android remains an Account hub child with back-to-Account behavior.
- Platform capability and responsive width are separate: width never decides whether a setting exists.

## Business behavior that must not change
- AppController remains the authority for autoStart, silentStart, autoUpdate, themeMode, language, networkMode, dnsMode and killSwitch.
- Launch-at-startup and silent-startup remain Windows/macOS-only.
- Available network modes remain filtered by CorePlatformSupport.supportsNetworkMode.
- Switching to TUN keeps the existing administrator-privilege check and warning toast before changing networkMode.
- setNetworkMode keeps the existing running-core transition behavior and switching toast.
- DNS changes keep using setDnsMode.
- Kill switch remains available only where the current system-proxy capability supports it and keeps using setKillSwitch.
- Repair network settings keeps using fixProxy and the existing success toast.
- Diagnostic output keeps SecureLogRedactor redaction for runtime logs and core errors, and keeps platform, connection state, proxy port and recorded-at metadata.
- Diagnostic copy keeps Clipboard behavior and success feedback.
- App/core version semantics remain unchanged; core version is still loaded through AppController.getCoreVersion().
- The non-HTTPS warning remains driven by AppConfig.isSecureServer.

## Presentation rule
The legacy desktop/compact branch, custom diagnostic button and raw FilledButton diagnostic action are not design references. Reuse shared AppSwitch, AppSelect, AppButton, adaptive modal/sheet and Greenfield spacing tokens.

## Validation gate
- flutter test
- flutter analyze
- sing-box desktop bridge
- Windows debug build
- macOS debug build
- Android remains separately tracked if pinned libbox AAR blocks before Kotlin/APK compilation.

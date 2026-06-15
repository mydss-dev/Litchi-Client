# Litchi Client

Cross-platform desktop VPN/proxy client built with Flutter (Windows + macOS).
Connects to V2Board-compatible panels, manages a local sing-box core, and
handles subscriptions, orders, and traffic statistics.

## Platform support

| Platform | Core connection | System proxy | Notes |
|----------|-----------------|--------------|-------|
| Windows  | ✅ | registry + WinInet | Full support |
| macOS    | ✅ system-proxy mode | `networksetup` | Requires `sing-box` placed next to the app / in `Contents/Resources`; the App Sandbox is disabled (ships outside the Mac App Store). TUN mode is not wired yet. |

On macOS, set the proxy mode to **system proxy** (TUN needs root + a network
extension and is not implemented). The bundled `sing-box` binary must be
executable (`chmod +x`).

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter (Windows desktop) |
| Panel API | V2Board-compatible REST (Dio) |
| Proxy core | sing-box (managed subprocess) |
| Runtime switching | Clash-compatible REST API |
| Settings persistence | SharedPreferences |
| Credential storage | Windows DPAPI (via PowerShell) |
| System proxy | Windows registry (`reg add`) |

## Prerequisites

- Flutter SDK ≥ 3.12 (`flutter --version`)
- Windows 10 / 11 (64-bit)
- `sing-box.exe` placed in the project root or `assets/` (not bundled)

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

## Project Structure

```
lib/
├── app/
│   ├── app_controller.dart       # Top-level coordinator (nav, auth, data)
│   ├── settings_controller.dart  # Settings state + SharedPrefs persistence
│   ├── core_controller.dart      # sing-box process + connection lifecycle
│   ├── app_shell.dart            # Root widget (auth vs main shell)
│   └── app_window_bar.dart       # Custom window title bar
│
├── features/                     # One folder per page/feature
│   ├── auth/                     # Login, register, change password
│   ├── dashboard/                # Connection toggle, node selector, traffic
│   ├── nodes/                    # Node list + latency testing
│   ├── shop/                     # Plans, order confirmation, payment dialog
│   ├── orders/                   # Order history
│   ├── traffic/                  # Usage charts
│   ├── invite/                   # Invite links + commission
│   ├── settings/                 # App preferences
│   └── account/                  # Profile + subscription info
│
├── shared/
│   ├── config/                   # AppConfig (API base URL, constants)
│   ├── models/                   # Data models + mappers
│   ├── services/                 # API client, sing-box config, parsers
│   ├── theme/                    # Colors, text styles, radius, shadows
│   └── widgets/                  # Reusable UI components
│
└── main.dart
```

## Key Services

| File | Responsibility |
|------|---------------|
| `services/panel_api.dart` | V2Board REST endpoints |
| `services/api_client.dart` | Dio HTTP client with auth |
| `services/subscription_parser.dart` | Base64 URI list + Clash YAML parsing |
| `services/outbound_parser.dart` | VMess / VLESS / Trojan / SS / Hysteria2 URI → sing-box outbound map |
| `services/singbox_config.dart` | Builds sing-box JSON config |
| `services/core_manager.dart` | Spawns / monitors sing-box subprocess |
| `services/singbox_api_client.dart` | Clash REST API (proxy switch, latency test) |
| `services/proxy_setter.dart` | Windows system proxy via registry |
| `services/credentials_storage.dart` | DPAPI-encrypted password storage |

## Development

```bash
# Static analysis (must be clean before committing)
flutter analyze

# Tests
flutter test

# Format
dart format lib/ test/
```

## Commit Convention

Format: `<type>(<scope>): <subject>`

| Type | When to use |
|------|------------|
| `feat` | New user-visible feature |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior change |
| `style` | Formatting, whitespace, missing semicolons |
| `chore` | Build, deps, tooling |
| `docs` | Documentation only |
| `test` | Adding or fixing tests |

Examples:
```
feat(shop): add coupon code field to order confirmation
fix(core): handle sing-box startup timeout on slow machines
refactor(controller): extract SettingsController from AppController
chore(deps): upgrade dio to 5.8.0
```

Rules:
- Subject line ≤ 72 characters, imperative mood ("add" not "added")
- `flutter analyze` must pass before committing
- No `--no-verify` bypasses

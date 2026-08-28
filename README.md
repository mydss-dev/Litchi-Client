# Litchi Client

Cross-platform VPN/proxy client built with Flutter.
Connects to V2Board-compatible panels, manages an embedded sing-box core, and
handles subscriptions, orders, and traffic statistics.

## Platform support

| Platform | Core connection | System proxy | Notes |
|----------|-----------------|--------------|-------|
| Windows  | sing-box dynamic library | registry + WinInet | System proxy and TUN configuration supported |
| macOS    | sing-box dynamic library | `networksetup` | Universal dynamic library; desktop TUN still requires system privileges |
| Android  | libbox AAR | VpnService | Native TUN FD integration with socket protection |
| Linux    | sing-box dynamic library | TUN | Desktop integration is under development |

On macOS, TUN uses a kernel-allocated `utun` interface and verifies that a new
interface appears before reporting a successful connection. Creating routes
still requires system privileges.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter (Windows, macOS, Android) |
| Panel API | V2Board-compatible REST (Dio) |
| Proxy core | sing-box (desktop dynamic library / Android libbox AAR) |
| Runtime switching | Clash-compatible REST API |
| Settings persistence | SharedPreferences |
| Credential storage | Windows DPAPI (via PowerShell) |
| System proxy | Windows registry (`reg add`) |

## Prerequisites

- Flutter SDK ≥ 3.12 (`flutter --version`)
- Windows 10 / 11 (64-bit)
- Go 1.24.7 for building the pinned sing-box libraries

> **Deploying or self-hosting?** See [ENVIRONMENT.md](ENVIRONMENT.md) for the exact GitHub Variables, Secrets, key generation, R2 layout, and release tutorial.

## Getting Started

```powershell
# Install dependencies
flutter pub get

# Apply local branding from config.json when needed
# (plain or signed config is supported for local tooling)
dart run tool/apply_branding.dart config.json

# Run in debug mode
flutter run -d windows

# Build release
flutter build windows --release
```

Set the OSS config URL and Ed25519 public keys at build time via
`--dart-define=REMOTE_CONFIG_URL=...`, `--dart-define=REMOTE_CONFIG_PUBLIC_KEY=...`
(remote config) and `--dart-define=UPDATE_PUBLIC_KEY=...` (update manifest). The
client rejects unsigned or invalid remote configuration. The application identity
is fixed so updates continue using the same data, credentials, auto-start entry,
and single-instance lock.

Only one CDN base URL is maintained (`CDN_BASE_URL`, e.g.
`https://cdn.example.com`). The client derives everything else from it:

- `REMOTE_CONFIG_URL` = `{CDN_BASE_URL}/config.json`
- update manifest URL = `{CDN_BASE_URL}/update.json` (derived at runtime as the
  sibling of the config URL)
- installer download URLs = `{CDN_BASE_URL}/download/<name>`

Panel API endpoints and branding values come exclusively from the signed
`config.json`. `api_base_list` provides panel API endpoints, while `app_name`
and `logo_url` are also used by CI to generate platform app names, package names,
and icons after the remote config signature verifies. There are no separate
`API_BASE`, `APP_NAME`, or `LOGO_URL` GitHub configuration values.

The two manifests use **independent Ed25519 keypairs**: `config.json` is signed
by the remote-config key, `update.json` by the update-manifest key.

Tagged releases fail when `CDN_BASE_URL`, `REMOTE_CONFIG_PUBLIC_KEY`, or
`UPDATE_PUBLIC_KEY` is missing/invalid (fail closed — no release client ships
without correctly verified remote configuration and update metadata). Android
tags publish both an APK for direct installation and an AAB for Google Play.

The signed `config.json` is maintained manually. `update.json` is not a
user-maintained file: do not create, edit, sign, or upload it by hand. Tagged CI
releases build all platform packages and create a GitHub Release; the separate
`.github/workflows/publish.yml` workflow automatically generates and signs
`update.json` with `UPDATE_PRIVATE_KEY`, uploads release packages under
`download/`, and uploads the signed manifest to R2.

## Project Structure

```
lib/
├── app/
│   ├── app_controller.dart       # Top-level coordinator (nav, auth, data)
│   ├── settings_controller.dart  # Settings state + SharedPrefs persistence
│   ├── core_controller.dart      # sing-box connection lifecycle
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
│   ├── config/                   # AppConfig (signed remote API/config values)
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
| `services/subscription_parser.dart` | Native sing-box JSON subscription parsing |
| `services/sing_box_config.dart` | Builds native sing-box JSON configuration |
| `services/sing_box_core_manager.dart` | Manages the desktop dynamic library lifecycle |
| `services/clash_api_client.dart` | Clash-compatible API (switching, group delay, traffic) |
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
|------|-------------|
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

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

## Getting Started

```powershell
# Install dependencies
flutter pub get

# Generate OS-level icons from the configured cloud logo
$env:LOGO_URL="https://your-oss.example/logo.png"
dart run tool/prepare_brand_assets.dart
dart run flutter_launcher_icons

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

Tagged releases fail when `API_BASE` is missing. Android tags publish both an
APK for direct installation and an AAB for Google Play.

The signed `config.json` is maintained manually. Tagged CI releases build all
platform packages and create a GitHub Release. Signing and the Cloudflare R2
upload run in a separate, manually-triggered workflow
(`.github/workflows/publish.yml`) under protected environments: it signs
`update-v2.json` with the independent update-manifest key and uploads the
packages and manifest to R2. `tool/publish_release.ps1` prepares and signs the
same update manifest locally.

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

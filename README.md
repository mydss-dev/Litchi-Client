# Litchi Client

Litchi Client is a Flutter desktop client for managing a subscription-panel
account, selecting proxy nodes, starting a local sing-box core, and switching
Windows system proxy settings.

## Tech Stack

- Flutter / Dart
- Windows desktop target
- `dio` for panel API requests
- `shared_preferences` for local preferences
- Windows DPAPI through PowerShell for stored credentials and auth token
- sing-box as the local proxy core

## Project Layout

```text
lib/
  app/                 App shell, navigation, global controller
  features/            Feature pages such as auth, dashboard, nodes, shop
  shared/config/       App-level constants
  shared/models/       Remote API models, UI models, and mappers
  shared/services/     API, storage, sing-box, proxy, and settings services
  shared/theme/        Theme tokens and Material themes
  shared/widgets/      Reusable UI widgets
```

## Local Development

Install dependencies:

```powershell
flutter pub get
```

Run the Windows app:

```powershell
flutter run -d windows
```

Use a custom panel API base URL:

```powershell
flutter run -d windows --dart-define=LITCHI_API_BASE=https://example.com
```

Run static analysis:

```powershell
flutter analyze
```

Run tests:

```powershell
flutter test
```

Build Windows release:

```powershell
flutter build windows
```

## sing-box Core

The app looks for `sing-box.exe` in these locations:

```text
<app executable directory>/sing-box.exe
<app executable directory>/core/sing-box.exe
%LOCALAPPDATA%/LitchiClient/sing-box.exe
```

During connection startup the app generates a sing-box JSON config, starts the
core process, waits for the local Clash-compatible API port, and then enables
the Windows system proxy.

## Configuration

The panel API base URL defaults to the value defined in:

```text
lib/shared/config/app_config.dart
```

Override it per run or build with:

```powershell
--dart-define=LITCHI_API_BASE=https://example.com
```

## Quality Checks

Before merging or shipping changes, run:

```powershell
flutter analyze
flutter test
```

For changes touching proxy startup, node parsing, or payment flow, also verify
the relevant UI manually because those paths depend on external services and a
local sing-box executable.

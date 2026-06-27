# Build Litchi Client with branding from config.json.
#
# Usage:
#   .\tool\build_from_config.ps1 windows   (or macos, android)
#
# Copy bot/config.sample.json to bot/config.json first, edit it, then run.

param(
  [ValidateSet("windows", "macos", "android")]
  [string]$Platform = "windows"
)

$configPath = "bot/config.json"
$samplePath = "bot/config.sample.json"
if (-not (Test-Path $configPath)) {
  Write-Error "$configPath not found. Copy $samplePath to $configPath and edit it."
  exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json

$appName = if ($config.app_name) { $config.app_name } else { "" }
$logoUrl = if ($config.logo_url) { $config.logo_url } else { "" }
$apiBase = if ($config.api_base_list -and $config.api_base_list[0]) { $config.api_base_list[0] } else { "" }
$version = if ($config.update_version) { $config.update_version } else { "" }

$flags = @()
if ($appName) { $flags += "--dart-define=APP_NAME=$appName" }
if ($logoUrl) { $flags += "--dart-define=LOGO_URL=$logoUrl" }
if ($apiBase) { $flags += "--dart-define=API_BASE=$apiBase" }
if ($version) { $flags += "--dart-define=APP_VERSION=$version" }

Write-Host "==> Building for $Platform" -ForegroundColor Cyan
Write-Host "    Name:    $appName"
Write-Host "    Logo:    ${logoUrl}"
Write-Host "    API:     $apiBase"
Write-Host "    Version: $version"
Write-Host ""

switch ($Platform) {
  "windows" {
    flutter build windows --release $flags
    Write-Host "`n==> Done. Output: build/windows/x64/runner/Release/" -ForegroundColor Green
  }
  "macos" {
    flutter build macos --release $flags
    Write-Host "`n==> Done. Output: build/macos/Build/Products/Release/" -ForegroundColor Green
  }
  "android" {
    flutter build apk --release $flags
    Write-Host "`n==> Done. Output: build/app/outputs/flutter-apk/" -ForegroundColor Green
  }
}

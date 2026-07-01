param(
  [ValidateSet("core", "run", "build")]
  [string]$Action = "run",
  [string]$DeviceId = "emulator-5554",
  [string]$Config = "$PSScriptRoot\..\local_test_config.json"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path "$PSScriptRoot\..").Path
$coreLibrary = Join-Path $root "android\app\src\main\jniLibs\arm64-v8a\liblitchi_mihomo.so"
$configPath = (Resolve-Path $Config -ErrorAction Stop).Path
$testConfig = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
  $defaultSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  if (-not (Test-Path $defaultSdk)) {
    throw "Android SDK not found. Install it or set ANDROID_HOME."
  }
  $env:ANDROID_HOME = $defaultSdk
  $env:ANDROID_SDK_ROOT = $defaultSdk
}

if ($Action -eq "core" -or -not (Test-Path $coreLibrary)) {
  & "$PSScriptRoot\build_mihomo_android.ps1"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
if ($Action -eq "core") {
  Write-Host "Android core ready: $coreLibrary"
  exit 0
}

$env:TENANT_ID = $testConfig.TENANT_ID
$env:NATIVE_APP_ID = if ($testConfig.NATIVE_APP_ID) { $testConfig.NATIVE_APP_ID } else { $testConfig.TENANT_ID }
$env:BUILD_VERSION = $testConfig.BUILD_VERSION
$env:REMOTE_CONFIG_URL = $testConfig.REMOTE_CONFIG_URL
$env:REMOTE_CONFIG_VERIFIER = $testConfig.REMOTE_CONFIG_VERIFIER
$githubOutput = Join-Path $env:TEMP "litchi-local-config-output.txt"
if (Test-Path $githubOutput) { Remove-Item $githubOutput -Force }
$env:GITHUB_OUTPUT = $githubOutput

Push-Location $root
try {
  & node tool/prepare_white_label_config.mjs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $outputs = @{}
  Get-Content $githubOutput | ForEach-Object {
    $parts = $_ -split "=", 2
    if ($parts.Length -eq 2) { $outputs[$parts[0]] = $parts[1] }
  }
  $env:LOGO_URL = $outputs.logo_url
  $env:ANDROID_APPLICATION_ID = $outputs.android_application_id

  & flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  & dart run tool/prepare_brand_assets.dart
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & dart run tool/apply_branding.dart $outputs.config_path --metadata-only
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & dart run flutter_launcher_icons
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  $defines = @(
    "--dart-define=APP_NAME=$($outputs.app_name)",
    "--dart-define=APP_ID=$env:NATIVE_APP_ID",
    "--dart-define=PUBLIC_APP_ID=$env:TENANT_ID",
    "--dart-define=LOGO_URL=$($outputs.logo_url)",
    "--dart-define=API_BASE=$($outputs.api_base)",
    "--dart-define=APP_VERSION=$($testConfig.BUILD_VERSION)",
    "--dart-define=REMOTE_CONFIG_URL=$($testConfig.REMOTE_CONFIG_URL)",
    "--dart-define=REMOTE_CONFIG_PUBLIC_KEY=$($testConfig.REMOTE_CONFIG_VERIFIER)"
  )

  if ($Action -eq "build") {
    & flutter build apk --debug @defines
  } else {
    & flutter run -d $DeviceId @defines
  }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
  Pop-Location
}

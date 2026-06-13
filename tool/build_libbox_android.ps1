param(
  [string]$Ref = "testing",
  [string]$WorkDir = "$PSScriptRoot\..\build\sing-box-src"
)

$ErrorActionPreference = "Stop"

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

Require-Command git
Require-Command go
Require-Command make

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
  throw "ANDROID_HOME or ANDROID_SDK_ROOT must be set"
}

$repo = "https://github.com/SagerNet/sing-box.git"
$root = Resolve-Path "$PSScriptRoot\.."
$libs = Join-Path $root "android\app\libs"

if (-not (Test-Path $WorkDir)) {
  git clone --depth 1 --branch $Ref $repo $WorkDir
} else {
  Push-Location $WorkDir
  git fetch --depth 1 origin $Ref
  git checkout FETCH_HEAD
  Pop-Location
}

Push-Location $WorkDir
try {
  make lib_install
  make lib_android
} finally {
  Pop-Location
}

$aar = Get-ChildItem -Path $WorkDir -Recurse -Filter "libbox.aar" |
  Select-Object -First 1

if (-not $aar) {
  throw "libbox.aar was not produced by the sing-box build"
}

New-Item -ItemType Directory -Force -Path $libs | Out-Null
Copy-Item $aar.FullName (Join-Path $libs "libbox.aar") -Force

$legacy = Get-ChildItem -Path $WorkDir -Recurse -Filter "libbox-legacy.aar" |
  Select-Object -First 1
if ($legacy) {
  Copy-Item $legacy.FullName (Join-Path $libs "libbox-legacy.aar") -Force
}

Write-Host "Copied libbox.aar to android/app/libs"

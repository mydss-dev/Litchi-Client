param(
  [string]$Ref = $(if ($env:LIBBOX_REF) { $env:LIBBOX_REF } else { "v1.13.13" }),
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
  $resolved = (git rev-parse HEAD).Trim()
  Write-Host "Building sing-box libbox from ref $Ref ($resolved)"
} finally {
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

# Deliberately NOT copying libbox-legacy.aar: it duplicates libbox.aar's
# io.nekohasekai.libbox classes and arm64-v8a/libbox.so, which breaks
# mergeReleaseNativeLibs. The modern libbox.aar covers our targets.

Write-Host "Copied libbox.aar to android/app/libs"

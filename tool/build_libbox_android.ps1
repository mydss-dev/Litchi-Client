param(
  [string]$Ref = $(if ($env:LIBBOX_REF) { $env:LIBBOX_REF } else { "" }),
  [string]$WorkDir = "$PSScriptRoot\..\build\sing-box-src"
)

$ErrorActionPreference = "Stop"
$versionsFile = Join-Path $PSScriptRoot "core_versions.env"

if (-not $Ref) {
  $versionLine = Get-Content $versionsFile | Where-Object {
    $_ -match '^SING_BOX_VERSION='
  } | Select-Object -First 1
  if (-not $versionLine) { throw "SING_BOX_VERSION is missing from $versionsFile" }
  $Ref = ($versionLine -split '=', 2)[1].Trim()
}
$commitLine = Get-Content $versionsFile | Where-Object {
  $_ -match '^SING_BOX_COMMIT='
} | Select-Object -First 1
if (-not $commitLine) { throw "SING_BOX_COMMIT is missing from $versionsFile" }
$expectedCommit = ($commitLine -split '=', 2)[1].Trim()

function Require-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing required command: $Name"
  }
}

Require-Command git
Require-Command go

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
  $java = Get-ChildItem "C:\Program Files\Eclipse Adoptium" `
    -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($java) {
    $env:JAVA_HOME = $java.Directory.Parent.FullName
    $env:Path = "$($java.DirectoryName);$env:Path"
  }
}
Require-Command java

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
  $defaultSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
  if (Test-Path $defaultSdk) {
    $env:ANDROID_HOME = $defaultSdk
    $env:ANDROID_SDK_ROOT = $defaultSdk
  } else {
    throw "ANDROID_HOME or ANDROID_SDK_ROOT must be set"
  }
}

if (-not (Get-Command make -ErrorAction SilentlyContinue)) {
  $make = Get-ChildItem `
    (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages") `
    -Recurse -Filter "make.exe" -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($make) {
    $env:Path = "$($make.DirectoryName);$env:Path"
  }
}
Require-Command make

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { $env:ANDROID_SDK_ROOT }
if (-not $env:ANDROID_NDK_HOME -and -not $env:ANDROID_NDK_ROOT) {
  $ndk = Get-ChildItem (Join-Path $sdk "ndk") -Directory -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending |
    Select-Object -First 1
  if (-not $ndk) {
    throw "Android NDK is not installed under $sdk\ndk"
  }
  $env:ANDROID_NDK_HOME = $ndk.FullName
  $env:ANDROID_NDK_ROOT = $ndk.FullName
}

$repo = "https://github.com/SagerNet/sing-box.git"
$root = Resolve-Path "$PSScriptRoot\.."
$libs = Join-Path $root "android\app\libs"
$goPath = (go env GOPATH).Trim()
if ($goPath) {
  $env:Path = "$(Join-Path $goPath 'bin');$env:Path"
}

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
  if ($resolved -ne $expectedCommit) {
    throw "sing-box commit mismatch: resolved=$resolved expected=$expectedCommit"
  }
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

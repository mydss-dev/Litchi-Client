param([string]$Ndk = "")

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$core = Join-Path $root "core\mihomo"
$jni = Join-Path $root "android\app\src\main\jniLibs"
$includes = Join-Path $root "android\app\src\main\cpp\includes"

if (-not $Ndk) {
  $Ndk = if ($env:ANDROID_NDK_HOME) {
    $env:ANDROID_NDK_HOME
  } elseif ($env:ANDROID_NDK_ROOT) {
    $env:ANDROID_NDK_ROOT
  } else {
    $sdkNdk = Join-Path $env:LOCALAPPDATA "Android\Sdk\ndk"
    if (Test-Path $sdkNdk) {
      (Get-ChildItem $sdkNdk -Directory | Sort-Object Name -Descending |
        Select-Object -First 1).FullName
    } else {
      ""
    }
  }
}

if (-not $Ndk -or -not (Test-Path $Ndk)) {
  throw "ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to an installed NDK"
}
$prebuilt = Get-ChildItem (Join-Path $Ndk "toolchains\llvm\prebuilt") -Directory |
  Select-Object -First 1
if (-not $prebuilt) { throw "Android NDK LLVM toolchain not found" }
$bin = Join-Path $prebuilt.FullName "bin"

$targets = @(
  @{ Abi = "arm64-v8a"; GoArch = "arm64"; Cc = "aarch64-linux-android21-clang.cmd" },
  @{ Abi = "armeabi-v7a"; GoArch = "arm"; Cc = "armv7a-linux-androideabi21-clang.cmd" },
  @{ Abi = "x86_64"; GoArch = "amd64"; Cc = "x86_64-linux-android21-clang.cmd" }
)

foreach ($target in $targets) {
  $outDir = Join-Path $jni $target.Abi
  $includeDir = Join-Path $includes $target.Abi
  New-Item -ItemType Directory -Force -Path $outDir, $includeDir | Out-Null
  $cc = Join-Path $bin $target.Cc
  if (-not (Test-Path $cc)) {
    $cc = $cc -replace '\.cmd$', '.exe'
  }
  if (-not (Test-Path $cc)) { throw "NDK compiler missing: $cc" }

  $env:GOOS = "android"
  $env:GOARCH = $target.GoArch
  $env:CGO_ENABLED = "1"
  $env:CC = $cc
  if ($target.GoArch -eq "arm") { $env:GOARM = "7" }
  $output = Join-Path $outDir "liblitchi_mihomo.so"
  Push-Location $core
  try {
    & go build -tags with_gvisor -trimpath -ldflags "-s -w -X main.version=v1.19.27" -buildmode=c-shared -o $output .
    if ($LASTEXITCODE -ne 0) { throw "mihomo Android build failed for $($target.Abi)" }
  } finally {
    Pop-Location
  }
  Copy-Item (Join-Path $outDir "liblitchi_mihomo.h") (Join-Path $includeDir "liblitchi_mihomo.h") -Force
  Copy-Item (Join-Path $core "bridge.h") (Join-Path $includeDir "bridge.h") -Force
}

Write-Host "mihomo Android libraries are ready"

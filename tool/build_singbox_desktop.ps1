param(
  [ValidateSet("windows", "linux", "darwin")]
  [string]$Target = $(if ($IsMacOS) { "darwin" } elseif ($IsLinux) { "linux" } else { "windows" }),
  [ValidateSet("amd64", "arm64")]
  [string]$Arch = $(if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" })
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$source = Join-Path $root "core\singbox"
$output = Join-Path $root "runtime\singbox\$Target-$Arch"
New-Item -ItemType Directory -Force -Path $output | Out-Null
$versionsFile = Join-Path $PSScriptRoot "core_versions.env"
$versionLine = Get-Content $versionsFile | Where-Object {
  $_ -match '^SING_BOX_VERSION='
} | Select-Object -First 1
if (-not $versionLine) { throw "SING_BOX_VERSION is missing from $versionsFile" }
$version = ($versionLine -split '=', 2)[1].Trim().TrimStart('v')

$extension = switch ($Target) {
  "windows" { ".dll" }
  "darwin" { ".dylib" }
  default { ".so" }
}
$env:GOOS = $Target
$env:GOARCH = $Arch
$env:CGO_ENABLED = "1"
if ($Target -eq "windows" -and -not $env:CC) {
  if (Get-Command gcc -ErrorAction SilentlyContinue) {
    $env:CC = "gcc"
  } elseif (Get-Command clang -ErrorAction SilentlyContinue) {
    $env:CC = "clang"
  } else {
    throw "A C compiler (gcc or clang) is required to build the sing-box DLL"
  }
}
$tags = "with_clash_api,with_quic,with_utls,with_wireguard"
$library = Join-Path $output "litchi_singbox$extension"

Push-Location $source
try {
  go mod download
  go build -trimpath -tags $tags -buildmode=c-shared -ldflags "-s -w -X github.com/sagernet/sing-box/constant.Version=$version-litchi" -o $library .
} finally {
  Pop-Location
}

Write-Host "sing-box desktop library ready: $library"

param(
  [Parameter(Mandatory=$true)]
  [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"

# Source core_versions.env so we only maintain versions in one place.
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir "core_versions.env"
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($key, $value)
    }
}

# ── mihomo ──────────────────────────────────────────────────────────
$version = $env:MIHOMO_VERSION
$name = "mihomo-windows-amd64-$version.zip"
$url = "https://github.com/MetaCubeX/mihomo/releases/download/$version/$name"
Write-Host "Downloading $name"
Invoke-WebRequest -Uri $url -OutFile mihomo.zip

$actual = (Get-FileHash mihomo.zip -Algorithm SHA256).Hash.ToLower()
$expected = $env:MIHOMO_WINDOWS_AMD64_SHA256.ToLower()
if ($actual -ne $expected) {
    throw "mihomo windows sha256 mismatch: actual=$actual expected=$expected"
}
Write-Host "mihomo windows sha256 verified"

Expand-Archive mihomo.zip -DestinationPath mihomo-tmp -Force
$exe = Get-ChildItem -Recurse -Filter "mihomo*.exe" mihomo-tmp | Select-Object -First 1
if (-not $exe) { throw "mihomo.exe missing from downloaded archive" }
Copy-Item $exe.FullName "$ReleaseDir\mihomo.exe"
Write-Host "mihomo.exe ready"

# ── wintun ───────────────────────────────────────────────────────────
$wintunVersion = $env:WINTUN_VERSION
$wintunUrl = "https://www.wintun.net/builds/wintun-$wintunVersion.zip"
Write-Host "Downloading wintun $wintunVersion"
Invoke-WebRequest -Uri $wintunUrl -OutFile wintun.zip

$actualWintun = (Get-FileHash wintun.zip -Algorithm SHA256).Hash.ToLower()
$expectedWintun = $env:WINTUN_SHA256.ToLower()
if ($actualWintun -ne $expectedWintun) {
    throw "wintun sha256 mismatch: actual=$actualWintun expected=$expectedWintun"
}
Write-Host "wintun sha256 verified"

Expand-Archive wintun.zip -DestinationPath wintun-tmp -Force
Copy-Item "wintun-tmp\wintun\bin\amd64\wintun.dll" "$ReleaseDir\wintun.dll"
Write-Host "wintun.dll ready"

# Cleanup
Remove-Item -Recurse -Force mihomo-tmp, wintun-tmp, mihomo.zip, wintun.zip -ErrorAction SilentlyContinue

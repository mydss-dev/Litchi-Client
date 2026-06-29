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

# ── geo databases ────────────────────────────────────────────────────
# mihomo needs these to evaluate GEOIP/GEOSITE rules (the panel's Clash
# config ends with `GEOIP,CN,DIRECT`). Ship them next to mihomo.exe so a
# fresh install never has to download them at first launch (which fails
# behind a firewall and leaves the core unable to start).
$geoBase = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/$($env:GEO_VERSION)"

function Fetch-Geo($fileName, $expectedSha) {
    $tmp = "$ReleaseDir\$fileName.part"
    $final = "$ReleaseDir\$fileName"
    Write-Host "Downloading $fileName ($($env:GEO_VERSION))"
    Invoke-WebRequest -Uri "$geoBase/$fileName" -OutFile $tmp
    if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "empty download: $fileName"
    }
    $actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
    if ([string]::IsNullOrWhiteSpace($expectedSha)) {
        Write-Host "  $fileName sha256 = $actual  (paste into core_versions.env to lock)"
    } elseif ($actual -ne $expectedSha.ToLower()) {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        throw "$fileName sha256 mismatch: actual=$actual expected=$expectedSha"
    } else {
        Write-Host "  $fileName sha256 verified"
    }
    # Verified — promote atomically (same dir → rename; partial .part never used).
    Move-Item -Path $tmp -Destination $final -Force
}

Fetch-Geo "country.mmdb" $env:GEOIP_MMDB_SHA256
Fetch-Geo "geosite.dat"  $env:GEOSITE_DAT_SHA256
Write-Host "geo databases ready"

# Cleanup
Remove-Item -Recurse -Force mihomo-tmp, wintun-tmp, mihomo.zip, wintun.zip -ErrorAction SilentlyContinue

# Refreshes the VENDORED geo databases and updates core_versions.env.
#
# Upstream only publishes a rolling "latest" release, so this always fetches the
# newest build. Reproducibility comes from committing the bytes, not from a tag.
#
#   Usage:  pwsh tool/update_geo.ps1     (or)     powershell -File tool\update_geo.ps1

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$geoDir = Join-Path $repoRoot "runtime\geo"
$envFile = Join-Path $scriptDir "core_versions.env"
New-Item -ItemType Directory -Force -Path $geoDir | Out-Null

$base = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest"
$map = [ordered]@{
    "country.mmdb" = "GEOIP_MMDB_SHA256"
    "geosite.dat"  = "GEOSITE_DAT_SHA256"
}

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing version file: $envFile"
}

$tempFiles = @{}
$hashes = [ordered]@{}

try {
    foreach ($name in $map.Keys) {
        $temp = Join-Path $geoDir ".$name.$([Guid]::NewGuid().ToString('N')).part"
        $tempFiles[$name] = $temp
        Write-Host "Downloading $name ..."
        Invoke-WebRequest -Uri "$base/$name" -OutFile $temp
        if (-not (Test-Path -LiteralPath $temp) -or (Get-Item -LiteralPath $temp).Length -eq 0) {
            throw "Empty download: $name"
        }
        $hashes[$map[$name]] = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLower()
    }

    # Only replace the committed snapshots after both downloads succeed.
    foreach ($name in $map.Keys) {
        Move-Item -LiteralPath $tempFiles[$name] -Destination (Join-Path $geoDir $name) -Force
    }

    $snapshot = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    $text = [IO.File]::ReadAllText($envFile)
    $text = [Text.RegularExpressions.Regex]::Replace(
        $text, '(?m)^GEO_SNAPSHOT=.*$', "GEO_SNAPSHOT=$snapshot")
    foreach ($key in $hashes.Keys) {
        $text = [Text.RegularExpressions.Regex]::Replace(
            $text, "(?m)^$key=.*$", "$key=$($hashes[$key])")
    }

    # Write UTF-8 without BOM so core_versions.env remains source-able by bash.
    $envTemp = "$envFile.$([Guid]::NewGuid().ToString('N')).tmp"
    try {
        [IO.File]::WriteAllText($envTemp, $text, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $envTemp -Destination $envFile -Force
    } finally {
        Remove-Item -LiteralPath $envTemp -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "Geo snapshot updated: $snapshot"
    foreach ($key in $hashes.Keys) {
        Write-Host ("{0}={1}" -f $key, $hashes[$key])
    }
    Write-Host "Updated runtime/geo and tool/core_versions.env. Commit both."
} finally {
    foreach ($temp in $tempFiles.Values) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

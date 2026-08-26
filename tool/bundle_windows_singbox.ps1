param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."
$release = Resolve-Path $ReleaseDir

& "$PSScriptRoot\build_singbox_desktop.ps1" -Target windows -Arch amd64
$library = Join-Path $root "runtime\singbox\windows-amd64\litchi_singbox.dll"
if (-not (Test-Path -LiteralPath $library)) {
  throw "sing-box DLL was not generated: $library"
}
Copy-Item -LiteralPath $library -Destination (Join-Path $release "litchi_singbox.dll") -Force

$versions = @{}
Get-Content "$PSScriptRoot\core_versions.env" | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
    $versions[$matches[1].Trim()] = $matches[2].Trim()
  }
}
$wintunVersion = $versions["WINTUN_VERSION"]
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$wintunArchive = Join-Path $tempRoot "wintun-$wintunVersion.zip"
$extractDirectory = Join-Path ([IO.Path]::GetTempPath()) "litchi-wintun-$PID"
try {
  Invoke-WebRequest "https://www.wintun.net/builds/wintun-$wintunVersion.zip" -OutFile $wintunArchive
  $actual = (Get-FileHash $wintunArchive -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $versions["WINTUN_SHA256"].ToLower()) {
    throw "wintun SHA-256 mismatch: $actual"
  }
  Expand-Archive $wintunArchive -DestinationPath $extractDirectory -Force
  Copy-Item -LiteralPath "$extractDirectory\wintun\bin\amd64\wintun.dll" -Destination (Join-Path $release "wintun.dll") -Force
} finally {
  Remove-Item -LiteralPath $wintunArchive -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $extractDirectory) {
    Remove-Item -LiteralPath $extractDirectory -Recurse -Force
  }
}

Write-Host "sing-box and Wintun bundled into $release"

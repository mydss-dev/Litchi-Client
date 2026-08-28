[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')]
  [string]$Version,

  [Parameter(Mandatory = $true)]
  [string]$DownloadBaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$Changelog,

  [string]$WindowsPackage = '',
  [string]$AndroidPackage = '',
  [string]$MacosPackage = '',
  [string]$OutputDirectory = "$PSScriptRoot\..\release_output"
)

# Signs update.json with the INDEPENDENT update-manifest keypair. This script
# must never hold R2 credentials or the remote-config key; it only prepares the
# release payload and signs it. Uploading is done by a separate job that has no
# signing key (see .github/workflows/publish.yml).
$ErrorActionPreference = 'Stop'
$signer = Join-Path $PSScriptRoot 'sign_update_manifest.dart'
$privateKey = $env:UPDATE_PRIVATE_KEY
$publicKey = $env:UPDATE_PUBLIC_KEY

if ([string]::IsNullOrWhiteSpace($privateKey)) {
  throw 'Set UPDATE_PRIVATE_KEY before signing the update manifest.'
}
if ([string]::IsNullOrWhiteSpace($publicKey)) {
  throw 'Set UPDATE_PUBLIC_KEY before signing the update manifest.'
}
if ($privateKey -notmatch '^[A-Za-z0-9_-]+$' -or $publicKey -notmatch '^[A-Za-z0-9_-]+$') {
  throw 'Signing keys must be base64url strings without padding.'
}
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
  throw 'Dart is required. Install Flutter/Dart and ensure dart is on PATH.'
}
$baseUri = $null
if (-not [Uri]::TryCreate($DownloadBaseUrl.TrimEnd('/') + '/', [UriKind]::Absolute, [ref]$baseUri) -or
    $baseUri.Scheme -ne 'https') {
  throw 'DownloadBaseUrl must be an absolute HTTPS URL.'
}

$packages = [ordered]@{}
foreach ($item in @(
  @{ Platform = 'windows'; Path = $WindowsPackage },
  @{ Platform = 'android'; Path = $AndroidPackage },
  @{ Platform = 'macos'; Path = $MacosPackage }
)) {
  if ([string]::IsNullOrWhiteSpace($item.Path)) { continue }
  $resolved = (Resolve-Path -LiteralPath $item.Path).Path
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "Package is not a file: $resolved"
  }
  $packages[$item.Platform] = $resolved
}
if ($packages.Count -eq 0) {
  throw 'Provide at least one package: -WindowsPackage, -AndroidPackage, or -MacosPackage.'
}

$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($outputPath) | Out-Null
$temporaryPath = Join-Path ([IO.Path]::GetTempPath()) ("litchi-release-" + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryPath) | Out-Null

function Write-Utf8Json {
  param([object]$Value, [string]$Path)
  $json = $Value | ConvertTo-Json -Depth 20
  [IO.File]::WriteAllText($Path, $json + "`n", [Text.UTF8Encoding]::new($false))
}

function Sign-Payload {
  param([string]$PayloadPath, [string]$Destination)
  $result = & dart run $signer sign-env $PayloadPath 2>&1
  if ($LASTEXITCODE -ne 0) { throw ($result -join [Environment]::NewLine) }
  [IO.File]::WriteAllText(
    $Destination,
    ($result -join [Environment]::NewLine) + [Environment]::NewLine,
    [Text.UTF8Encoding]::new($false)
  )
  Get-Content -LiteralPath $Destination -Raw | ConvertFrom-Json | Out-Null
}

try {
  $downloadUrls = [ordered]@{}
  $hashes = [ordered]@{}

  foreach ($entry in $packages.GetEnumerator()) {
    $fileName = [IO.Path]::GetFileName($entry.Value)
    $destination = Join-Path $outputPath $fileName
    Copy-Item -LiteralPath $entry.Value -Destination $destination -Force
    $downloadUrls[$entry.Key] = [Uri]::new($baseUri, [Uri]::EscapeDataString($fileName)).AbsoluteUri
    $hashes[$entry.Key] = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
  }

  $updatePayload = [ordered]@{
    update_version = $Version
    update_download_url = $downloadUrls
    update_sha256 = $hashes
    update_changelog = $Changelog
  }
  $unsignedUpdate = Join-Path $temporaryPath 'update_payload.json'
  Write-Utf8Json $updatePayload $unsignedUpdate

  # Sign the manifest with the update-manifest key.
  Sign-Payload $unsignedUpdate (Join-Path $outputPath 'update.json')

  Write-Host "Release $Version prepared in $outputPath"
  foreach ($platform in $downloadUrls.Keys) {
    Write-Host "$platform  $($downloadUrls[$platform])"
    Write-Host "sha256   $($hashes[$platform])"
  }
} finally {
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Recurse -Force
  }
}

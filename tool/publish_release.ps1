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
  [string]$OutputDirectory = "$PSScriptRoot\..\release_output",
  [switch]$UploadToR2,
  [string]$RcloneRemote = ''
)

$ErrorActionPreference = 'Stop'
$signer = Join-Path $PSScriptRoot 'sign_remote_config.dart'
$privateKey = $env:LITCHI_CONFIG_PRIVATE_KEY
$publicKey = $env:LITCHI_CONFIG_PUBLIC_KEY

if ([string]::IsNullOrWhiteSpace($privateKey)) {
  throw 'Set LITCHI_CONFIG_PRIVATE_KEY before publishing.'
}
if ([string]::IsNullOrWhiteSpace($publicKey)) {
  throw 'Set LITCHI_CONFIG_PUBLIC_KEY before publishing.'
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
  Sign-Payload $unsignedUpdate (Join-Path $outputPath 'update.json')

  Write-Host "Release $Version prepared in $outputPath"
  foreach ($platform in $downloadUrls.Keys) {
    Write-Host "$platform  $($downloadUrls[$platform])"
    Write-Host "sha256   $($hashes[$platform])"
  }

  if (-not [string]::IsNullOrWhiteSpace($RcloneRemote)) {
    if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
      throw 'RcloneRemote was provided, but rclone is not installed.'
    }
    & rclone copy $outputPath $RcloneRemote --checksum
    if ($LASTEXITCODE -ne 0) { throw "rclone upload failed with exit code $LASTEXITCODE" }
    Write-Host "Uploaded release files to $RcloneRemote"
  }

  if ($UploadToR2) {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
      throw 'Python is required for Cloudflare R2 upload.'
    }
    foreach ($name in @('R2_ACCOUNT_ID', 'R2_ACCESS_KEY_ID', 'R2_SECRET_ACCESS_KEY', 'R2_BUCKET')) {
      if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "Set $name before uploading to Cloudflare R2."
      }
    }
    $env:DOWNLOAD_BASE_URL = $DownloadBaseUrl.TrimEnd('/')
    & python -c "import boto3" 2>$null
    if ($LASTEXITCODE -ne 0) {
      & python -m pip install --disable-pip-version-check boto3
      if ($LASTEXITCODE -ne 0) { throw 'Failed to install boto3.' }
    }
    $uploadFiles = @((Join-Path $outputPath 'update.json'))
    foreach ($entry in $packages.GetEnumerator()) {
      $uploadFiles += Join-Path $outputPath ([IO.Path]::GetFileName($entry.Value))
    }
    & python (Join-Path $PSScriptRoot 'upload_r2.py') @uploadFiles
    if ($LASTEXITCODE -ne 0) { throw "Cloudflare R2 upload failed with exit code $LASTEXITCODE" }
    Write-Host 'Cloudflare R2 release upload complete.'
  }
} finally {
  if (Test-Path -LiteralPath $temporaryPath) {
    Remove-Item -LiteralPath $temporaryPath -Recurse -Force
  }
}

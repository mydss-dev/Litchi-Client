$ErrorActionPreference = 'Stop'

Write-Host "Installing Inno Setup..."
choco install innosetup --no-progress -y --force

$isccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
)

$cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($cmd) {
  $isccCandidates += $cmd.Source
}

$iscc = $isccCandidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $iscc) {
  throw "ISCC.exe not found after installing Inno Setup"
}

$innoDir = Split-Path $iscc
$langDir = Join-Path $innoDir 'Languages'
$isl = Join-Path $langDir 'ChineseSimplified.isl'
New-Item -ItemType Directory -Force -Path $langDir | Out-Null

$needsDownload = $true
if (Test-Path $isl) {
  $existing = Get-Item $isl
  if ($existing.Length -gt 10000) {
    $needsDownload = $false
    Write-Host "ChineseSimplified.isl already exists: $isl"
  }
}

if ($needsDownload) {
  $urls = @(
    'https://raw.githubusercontent.com/kira-96/Inno-Setup-Chinese-Simplified-Translation/main/ChineseSimplified.isl',
    'https://raw.githubusercontent.com/eneiasramos/jrsoftware_issrc/main/Files/Languages/Unofficial/ChineseSimplified.isl'
  )

  $tmp = Join-Path $env:TEMP 'ChineseSimplified.isl'
  $downloaded = $false

  foreach ($url in $urls) {
    try {
      Write-Host "Downloading ChineseSimplified.isl from $url"
      Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
      $content = Get-Content $tmp -Raw -Encoding UTF8
      if ($content -notmatch '\[LangOptions\]' -or $content -notmatch '\[Messages\]') {
        throw 'Downloaded file is not a valid Inno Setup language file'
      }

      # Write UTF-8 with BOM. This avoids garbled Chinese on older Inno/Windows environments.
      [System.IO.File]::WriteAllText($isl, $content, [System.Text.UTF8Encoding]::new($true))
      $downloaded = $true
      break
    } catch {
      Write-Warning "Failed to download from $url: $($_.Exception.Message)"
    }
  }

  if (-not $downloaded) {
    throw 'Failed to download ChineseSimplified.isl from all mirrors'
  }
}

if (-not (Select-String -Path $isl -Pattern '^\[Messages\]' -Quiet)) {
  throw "ChineseSimplified.isl validation failed: $isl"
}

if ($env:GITHUB_PATH) {
  Add-Content $env:GITHUB_PATH $innoDir
}

Write-Host "Inno Setup ready: $iscc"
Write-Host "Chinese language file ready: $isl"

# Token sweep for lib/v3 — MUST use .NET UTF-8 APIs.
# Get-Content/Set-Content in Windows PowerShell 5.1 read UTF-8 as the system
# ANSI codepage (GBK on zh-CN Windows) and corrupt every Chinese literal.
$root = Join-Path $PSScriptRoot "..\lib\v3"

$map = [ordered]@{
  'BorderRadius.circular(8)'  = 'BorderRadius.circular(V3Radius.control)'
  'BorderRadius.circular(9)'  = 'BorderRadius.circular(V3Radius.control)'
  'BorderRadius.circular(10)' = 'BorderRadius.circular(V3Radius.control)'
  'BorderRadius.circular(11)' = 'BorderRadius.circular(V3Radius.control)'
  'BorderRadius.circular(12)' = 'BorderRadius.circular(V3Radius.field)'
  'BorderRadius.circular(13)' = 'BorderRadius.circular(V3Radius.field)'
  'BorderRadius.circular(14)' = 'BorderRadius.circular(V3Radius.field)'
  'BorderRadius.circular(15)' = 'BorderRadius.circular(V3Radius.field)'
  'BorderRadius.circular(16)' = 'BorderRadius.circular(V3Radius.card)'
  'BorderRadius.circular(17)' = 'BorderRadius.circular(V3Radius.card)'
  'BorderRadius.circular(18)' = 'BorderRadius.circular(V3Radius.card)'
  'BorderRadius.circular(20)' = 'BorderRadius.circular(V3Radius.card)'
  'BorderRadius.circular(22)' = 'BorderRadius.circular(V3Radius.panel)'
  'BorderRadius.circular(24)' = 'BorderRadius.circular(V3Radius.panel)'
  'BorderRadius.circular(26)' = 'BorderRadius.circular(V3Radius.panel)'
  'BorderRadius.circular(28)' = 'BorderRadius.circular(V3Radius.panel)'
  'BorderRadius.circular(30)' = 'BorderRadius.circular(V3Radius.panel)'
  'fontSize: 10.5' = 'fontSize: 10'
  'fontSize: 11.5' = 'fontSize: 11'
  'fontSize: 12.5' = 'fontSize: 12'
}

# Sanity check: the file must decode as UTF-8 without replacement characters.
$utf8 = New-Object System.Text.UTF8Encoding($false)
$changed = 0
Get-ChildItem -Recurse $root -Filter *.dart | ForEach-Object {
  $path = $_.FullName
  $text = [System.IO.File]::ReadAllText($path, $utf8)
  if ($text.Contains([char]0xFFFD)) {
    throw "REPLACEMENT CHARACTER in $path - aborting, file may be corrupted"
  }
  $original = $text
  foreach ($key in $map.Keys) { $text = $text.Replace($key, $map[$key]) }
  if ($text -ne $original) {
    [System.IO.File]::WriteAllText($path, $text, $utf8)
    $changed++
    Write-Output "changed: $($_.Name)"
  }
}
Write-Output "changed files: $changed"

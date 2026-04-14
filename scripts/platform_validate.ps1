<#!
.SYNOPSIS
  Validate multi-platform chapter outputs against gates defined in a JSON config.

.DESCRIPTION
  PowerShell equivalent of scripts/platform_validate.py.
  - Computes metrics on body only (content before marker "## 作者有话说").
  - Computes afterword metrics on content after the marker.
  - Outputs JSON array with a per-file record including meetsAll.

.USAGE
  ./scripts/platform_validate.ps1 -ConfigPath "SOP执行日志/平台校验_1.1.14_2026-02-08.config.json" -OutPath "SOP执行日志/平台校验_1.1.14_2026-02-08.json"

.NOTES
  Avoids printing chapter正文内容; only outputs metrics.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [Parameter()]
  [string]$OutPath = ""
)

Set-StrictMode -Version Latest

$CjkRe = [regex]'[\u4e00-\u9fff]'
$WordRe = [regex]"[A-Za-z]+(?:'[A-Za-z]+)?|\d+"

function Get-JsonProp {
  param(
    [Parameter(Mandatory = $true)]$Obj,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)]$Default
  )

  if ($null -eq $Obj) { return $Default }
  $p = $Obj.PSObject.Properties[$Name]
  if ($null -eq $p) { return $Default }
  $v = $p.Value
  if ($null -eq $v) { return $Default }
  return $v
}

function Read-TextBestEffort {
  param([Parameter(Mandatory=$true)][string]$Path)

  function Read-FileShared {
    param(
      [Parameter(Mandatory=$true)][string]$ResolvedPath,
      [Parameter(Mandatory=$true)][System.Text.Encoding]$Encoding
    )

    $fs = $null
    $sr = $null
    try {
      $fs = [System.IO.File]::Open($ResolvedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      $sr = New-Object System.IO.StreamReader($fs, $Encoding, $true)
      return $sr.ReadToEnd()
    } finally {
      if ($null -ne $sr) { $sr.Dispose() }
      if ($null -ne $fs) { $fs.Dispose() }
    }
  }

  $resolved = $null
  try {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  } catch {
    return ""
  }

  try {
    # Prefer shared read to tolerate OneDrive/editor file locks.
    return Read-FileShared -ResolvedPath $resolved -Encoding ([System.Text.Encoding]::UTF8)
  } catch {
    try {
      return Read-FileShared -ResolvedPath $resolved -Encoding ([System.Text.Encoding]::Default)
    } catch {
      try {
        $gb18030 = [System.Text.Encoding]::GetEncoding(54936)
        return Read-FileShared -ResolvedPath $resolved -Encoding $gb18030
      } catch {
        return ""
      }
    }
  }
}

function Get-MarkerCn {
  # Build "## 作者有话说" from code points for Windows PowerShell 5.1 stability.
  return '## ' + ([char]0x4F5C) + ([char]0x8005) + ([char]0x6709) + ([char]0x8BDD) + ([char]0x8BF4)
}

function Get-Markers {
  # Support both Chinese and English markers across platforms.
  return @(
    (Get-MarkerCn),
    "## Author's Note"
  )
}

function Split-BodyAfterword {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Text,
    [Parameter(Mandatory=$true)][string]$Marker
  )

  if ([string]::IsNullOrEmpty($Text)) {
    return ,@("", "", $false)
  }

  $idx = $Text.IndexOf($Marker, [System.StringComparison]::Ordinal)
  if ($idx -ge 0) {
    $body = $Text.Substring(0, $idx)
    $after = $Text.Substring($idx + $Marker.Length)
    $after = ($after -replace '^\s+', '')
    return ,@($body, $after, $true)
  }

  return ,@($Text, "", $false)
}

function Test-Gate {
  param(
    [Parameter(Mandatory=$true)][hashtable]$M,
    [Parameter(Mandatory=$true)][hashtable]$Gate
  )

  if (-not $M.exists) { return $false }

  if ($Gate['minLen'] -and ($M.len -lt $Gate['minLen'])) { return $false }
  if ($Gate['minCJK'] -and ($M.cjk -lt $Gate['minCJK'])) { return $false }
  if ($Gate['maxCJK'] -and ($M.cjk -gt $Gate['maxCJK'])) { return $false }
  if ($Gate['maxLen'] -and ($M.len -gt $Gate['maxLen'])) { return $false }

  if ($null -ne $Gate['minTotalCJK'] -and ($M.totalCJK -lt $Gate['minTotalCJK'])) { return $false }
  if ($null -ne $Gate['maxTotalCJK'] -and ($M.totalCJK -gt $Gate['maxTotalCJK'])) { return $false }

  if ($Gate['requireAfterword'] -and (-not $M.hasAfterword)) { return $false }

  if ($Gate['minAfterwordCJK'] -and ($M.afterwordCJK -lt $Gate['minAfterwordCJK'])) { return $false }
  if ($Gate['maxAfterwordCJK'] -and ($M.afterwordCJK -gt $Gate['maxAfterwordCJK'])) { return $false }
  if ($Gate['minAfterwordWords'] -and ($M.afterwordWords -lt $Gate['minAfterwordWords'])) { return $false }
  if ($Gate['maxAfterwordWords'] -and ($M.afterwordWords -gt $Gate['maxAfterwordWords'])) { return $false }

  return $true
}

# Load config
if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$cfgText = Read-TextBestEffort -Path $ConfigPath
$cfg = $cfgText | ConvertFrom-Json
$items = @($cfg.files)

$defaultMarker = Get-MarkerCn
$markers = Get-Markers
$out = @()

foreach ($item in $items) {
  $platform = [string]$item.platform
  $path = [string]$item.path

  $minTotalCJKProp = $item.PSObject.Properties['minTotalCJK']
  $maxTotalCJKProp = $item.PSObject.Properties['maxTotalCJK']

  $gate = @{
    minLen            = [int](Get-JsonProp -Obj $item -Name 'minLen' -Default 0)
    minCJK            = [int](Get-JsonProp -Obj $item -Name 'minCJK' -Default 0)
    maxCJK            = [int](Get-JsonProp -Obj $item -Name 'maxCJK' -Default 0)
    maxLen            = [int](Get-JsonProp -Obj $item -Name 'maxLen' -Default 0)
    minTotalCJK       = $(if ($null -ne $minTotalCJKProp -and $null -ne $minTotalCJKProp.Value) { [int]$minTotalCJKProp.Value } else { $null })
    maxTotalCJK       = $(if ($null -ne $maxTotalCJKProp -and $null -ne $maxTotalCJKProp.Value) { [int]$maxTotalCJKProp.Value } else { $null })
    requireAfterword  = [bool](Get-JsonProp -Obj $item -Name 'requireAfterword' -Default $false)
    minAfterwordCJK   = [int](Get-JsonProp -Obj $item -Name 'minAfterwordCJK' -Default 0)
    maxAfterwordCJK   = [int](Get-JsonProp -Obj $item -Name 'maxAfterwordCJK' -Default 0)
    minAfterwordWords = [int](Get-JsonProp -Obj $item -Name 'minAfterwordWords' -Default 0)
    maxAfterwordWords = [int](Get-JsonProp -Obj $item -Name 'maxAfterwordWords' -Default 0)
  }

  $marker = [string](Get-JsonProp -Obj $item -Name 'afterwordMarker' -Default $defaultMarker)

  $exists = Test-Path -LiteralPath $path

  $m = @{
    exists        = $exists
    hasAfterword  = $false
    totalLen      = 0
    totalCJK      = 0
    len           = 0
    cjk           = 0
    lines         = 0
    afterwordLen  = 0
    afterwordCJK  = 0
    afterwordWords= 0
  }

  if ($exists) {
    $text = Read-TextBestEffort -Path $path
    if ($null -eq $text) { $text = "" }
    if (-not ($text -is [string])) { $text = ($text | Out-String) }

    $m.totalLen = $text.Length
    $m.totalCJK = $CjkRe.Matches($text).Count

    # Split strictly by the marker specified in config.
    # SOP口径：正文以“## 作者有话说”前为准（或config显式指定的marker）。
    # NOTE: Do NOT fall back to other markers here; fallback can cause false splits
    # when a different marker string appears inside body text (e.g. English platforms
    # or embedded notes), breaking length/CJK gates.
    $candidateMarkers = @()
    if ($marker) {
      $candidateMarkers += @([string]$marker)
    } else {
      # If config doesn't specify, allow known markers.
      $candidateMarkers += @($markers)
    }

    $best = $null
    $bestIdx = -1
    foreach ($mk in $candidateMarkers) {
      $idx = $text.IndexOf([string]$mk, [System.StringComparison]::Ordinal)
      if ($idx -ge 0 -and ($bestIdx -lt 0 -or $idx -lt $bestIdx)) {
        $bestIdx = $idx
        $best = [string]$mk
      }
    }

    $parts = if ($bestIdx -ge 0) { Split-BodyAfterword -Text $text -Marker $best } else { ,@($text, "", $false) }
    $body = [string]$parts[0]
    $after = [string]$parts[1]
    $hasAfter = [bool]$parts[2]

    $m.hasAfterword = $hasAfter
    $m.len = $body.Length
    $m.cjk = $CjkRe.Matches($body).Count
    $m.lines = ($body -split "`r?`n").Length

    $m.afterwordLen = $after.Length
    $m.afterwordCJK = $CjkRe.Matches($after).Count
    $m.afterwordWords = $WordRe.Matches($after).Count
  }

  $record = [ordered]@{
    platform         = $platform
    path             = $path
    afterwordMarker  = $marker
    minLen           = $gate['minLen']
    minCJK           = $gate['minCJK']
    maxCJK           = $gate['maxCJK']
    maxLen           = $gate['maxLen']
    minTotalCJK      = $gate['minTotalCJK']
    maxTotalCJK      = $gate['maxTotalCJK']
    requireAfterword = $gate['requireAfterword']
    minAfterwordCJK  = $gate['minAfterwordCJK']
    maxAfterwordCJK  = $gate['maxAfterwordCJK']
    minAfterwordWords= $gate['minAfterwordWords']
    maxAfterwordWords= $gate['maxAfterwordWords']
    exists           = $m.exists
    hasAfterword     = $m.hasAfterword
    totalLen         = $m.totalLen
    totalCJK         = $m.totalCJK
    len              = $m.len
    cjk              = $m.cjk
    lines            = $m.lines
    afterwordLen     = $m.afterwordLen
    afterwordCJK     = $m.afterwordCJK
    afterwordWords   = $m.afterwordWords
  }

  $record.meetsAll = Test-Gate -M $m -Gate $gate
  $out += [pscustomobject]$record
}

$json = $out | ConvertTo-Json -Depth 6

if ($OutPath) {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
} else {
  $json
}

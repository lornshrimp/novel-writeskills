<#
.SYNOPSIS
  Run POV drift validation for files listed in a platform config.

.DESCRIPTION
  Uses scripts/pov_validate.py per file and writes a JSON summary.
  Does not print chapter正文.
  Always exits 0 (safe for SOP pipelines); rely on printed PASS/FAIL.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigPath,

  [Parameter(Mandatory=$true)]
  [string]$OutPath,

  [Parameter()]
  [ValidateSet('first','second','third')]
  [string]$Expected = 'third',

  [Parameter()]
  [ValidateSet('zh','en','auto')]
  [string]$Lang = 'auto'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config not found: $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$items = @($cfg.files)
if (-not $items -or $items.Count -eq 0) {
  throw "Config has no files: $ConfigPath"
}

$results = @()
foreach ($it in $items) {
  $p = [string]$it.path
  $raw = & python scripts/pov_validate.py --lang $Lang --expected $Expected --path $p
  $j = $raw | ConvertFrom-Json
  $results += $j
}

$fails = @($results | Where-Object { -not $_.pass })
$summary = [pscustomobject]@{
  tool = 'pov_validate'
  generatedAt = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
  expected = $Expected
  lang = $Lang
  allPass = ($fails.Count -eq 0)
  failCount = $fails.Count
  results = $results
}

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8

if ($fails.Count -eq 0) {
  Write-Output 'ALL_PASS'
  Write-Output ("WROTE: {0}" -f $OutPath)
  exit 0
}

Write-Output ("FAIL_COUNT={0}" -f $fails.Count)
$fails | ForEach-Object {
  $c1 = $_.counts.first
  $c2 = $_.counts.second
  $reasons = ($_.reasons -join '; ')
  Write-Output ("{0}\texpected={1}; lang={2}; pass={3}; counts.first={4}; counts.second={5}; reasons={6}" -f $_.path, $_.expected, $_.lang, $_.pass, $c1, $c2, $reasons)
}
Write-Output ("WROTE: {0}" -f $OutPath)
exit 0

<#
.SYNOPSIS
  Run text quality scan for files listed in a platform config.

.DESCRIPTION
  Wraps scripts/scan_text_quality.ps1.
  Writes a JSON report and prints a concise summary (no正文).
  Always exits 0 (safe for SOP pipelines).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$ConfigPath,

  [Parameter(Mandatory=$true)]
  [string]$OutPath
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

$paths = @($items | ForEach-Object { $_.path })

# scan_text_quality writes JSON to OutPath and prints only WROTE.
& ./scripts/scan_text_quality.ps1 -Paths $paths -OutPath $OutPath | Out-Null

$j = Get-Content -LiteralPath $OutPath -Raw -Encoding UTF8 | ConvertFrom-Json

$results = @($j.results)
$flagged = @($results | Where-Object { $_.flags -and @($_.flags).Count -gt 0 })

if ($flagged.Count -eq 0) {
  Write-Output 'QUALITY_ALL_CLEAR'
  Write-Output ("WROTE: {0}" -f $OutPath)
  exit 0
}

Write-Output ("QUALITY_FLAGGED_FILES={0}" -f $flagged.Count)
$flagged | ForEach-Object {
  $flags = (@($_.flags) -join ',')
  Write-Output ("{0}\tflags={1}" -f $_.path, $flags)
}
Write-Output ("WROTE: {0}" -f $OutPath)
exit 0

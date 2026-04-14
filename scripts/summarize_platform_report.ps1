<#
.SYNOPSIS
  Summarize platform gate validation report (platform_validate.ps1 output).

.DESCRIPTION
  Prints per-platform key metrics and a failure list.
  Safe: does not print chapter body text.

.USAGE
  ./scripts/summarize_platform_report.ps1 -ReportPath "SOP执行日志/平台校验_1.1.37_2026-02-17_RECHECK.v2.json"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReportPath
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ReportPath)) {
  throw "Report not found: $ReportPath"
}

$j = Get-Content -LiteralPath $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

$j |
  Sort-Object platform |
  Select-Object platform, meetsAll, cjk, minCJK, afterwordCJK, minAfterwordCJK, maxAfterwordCJK, hasAfterword |
  Format-Table -AutoSize

$fails = @($j | Where-Object { -not $_.meetsAll })
Write-Host ("FAIL_COUNT={0}" -f $fails.Count)

if ($fails.Count -gt 0) {
  $fails |
    Sort-Object platform |
    Select-Object platform, cjk, minCJK, afterwordCJK, minAfterwordCJK, maxAfterwordCJK, hasAfterword, afterwordMarker |
    Format-Table -AutoSize
}

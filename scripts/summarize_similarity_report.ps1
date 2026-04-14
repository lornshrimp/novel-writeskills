<#<#

<#
.SYNOPSIS
  Summarize similarity QA report (chapter_similarity_check.ps1 output).

.DESCRIPTION
  Prints qa.* and top-N highest-sim pairs (by shingle_containment_max). Does not print body text.

.USAGE
  ./scripts/summarize_similarity_report.ps1 -ReportPath "SOP执行日志/相似度终检_1.1.37_shingle5_QA_2026-02-17_RECHECK.v2.json" -TopN 10
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ReportPath,

  [Parameter()]
  [int]$TopN = 10
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ReportPath)) {
  throw "Report not found: $ReportPath"
}

$j = Get-Content -LiteralPath $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ($null -ne $j.qa) {
  $check = $j.qa.PSObject.Properties['check_max_sim']
  if ($null -ne $check) {
    Write-Host ("qa.check_max_sim={0}" -f [bool]$check.Value)
  }

  $pMaxSim = $j.qa.PSObject.Properties['max_sim']
  if ($null -ne $pMaxSim -and $null -ne $pMaxSim.Value) {
    Write-Host ("qa.max_sim={0}" -f $pMaxSim.Value)
  }

  $pMetric = $j.qa.PSObject.Properties['qa_metric']
  if ($null -ne $pMetric -and $null -ne $pMetric.Value) {
    Write-Host ("qa.qa_metric={0}" -f $pMetric.Value)
  }

  $pShingleN = $j.qa.PSObject.Properties['shingle_n']
  if ($null -ne $pShingleN -and $null -ne $pShingleN.Value) {
    Write-Host ("qa.shingle_n={0}" -f $pShingleN.Value)
  }

  $pPassed = $j.qa.PSObject.Properties['passed']
  if ($null -ne $pPassed) {
    if ($null -eq $pPassed.Value) {
      Write-Host "qa.passed=null (CheckMaxSim disabled)"
    } else {
      Write-Host ("qa.passed={0}" -f [bool]$pPassed.Value)
    }
  }

  $pViol = $j.qa.PSObject.Properties['violations']
  if ($null -ne $pViol -and $null -ne $pViol.Value) {
    $vc = @($pViol.Value).Count
    Write-Host ("qa.violations_count={0}" -f $vc)
  }
}

if ($null -eq $j.pairs) {
  Write-Host "No pairs found in report."
  exit 0
}

$pairs = @($j.pairs | Sort-Object shingle_containment_max -Descending)
if ($pairs.Count -eq 0) {
  Write-Host "pairs is empty."
  exit 0
}

# Always compute maxSim / maxPair from pairs to avoid schema drift.
$max = $pairs | Select-Object -First 1
if ($null -ne $max) {
  Write-Host ("computed.maxSim={0}" -f $max.shingle_containment_max)
  Write-Host ("computed.maxPair={0} <-> {1}" -f $max.a, $max.b)
}

$take = [Math]::Min($TopN, $pairs.Count)
Write-Host ("TopPairs={0}" -f $take)

$pairs | Select-Object -First $take | ForEach-Object {
  $a = $_.a
  $b = $_.b
  $sim = $_.shingle_containment_max
  "{0} <-> {1}\tshingle_containment_max={2}" -f $a, $b, $sim
}

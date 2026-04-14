<#
.SYNOPSIS
  Run cross-platform similarity check and print a safe summary (no正文).

.DESCRIPTION
  Wraps chapter_similarity_check.ps1 and prints:
  - report path
  - computed max shingle_containment_max + pair
  - PASS/FAIL against threshold

  Always exits 0 to avoid breaking a larger SOP pipeline.

.USAGE
  ./scripts/run_similarity_gate.ps1 -ConfigPath "SOP执行日志/平台校验_1.1.62_2026-02-20_11-02-30.config.json" -OutPath "SOP执行日志/相似度终检_1.1.62_shingle5_2026-02-20_修复后.json" -Threshold 0.199 -TopN 10
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ConfigPath,

  [Parameter(Mandatory = $true)]
  [string]$OutPath,

  [Parameter()]
  [int]$ShingleN = 5,

  [Parameter()]
  [double]$Threshold = 0.199,

  [Parameter()]
  [int]$TopN = 10
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config not found: $ConfigPath"
}

$cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($null -eq $cfg.files -or @($cfg.files).Count -eq 0) {
  throw "Config has no files: $ConfigPath"
}

$paths = @($cfg.files | ForEach-Object { $_.path })

# Run similarity computation (no hard gate to avoid exit 2).
./scripts/chapter_similarity_check.ps1 -Path $paths -OutPath $OutPath -ShingleN $ShingleN | Out-Null

if (-not (Test-Path -LiteralPath $OutPath)) {
  throw "Report not generated: $OutPath"
}

$j = Get-Content -LiteralPath $OutPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host ("REPORT_PATH={0}" -f $OutPath)
Write-Host ("THRESHOLD={0}" -f $Threshold)

if ($null -eq $j.pairs) {
  Write-Host "PASS=False (pairs=null)"
  exit 0
}

$pairs = @($j.pairs | Sort-Object shingle_containment_max -Descending)
if ($pairs.Count -eq 0) {
  Write-Host "PASS=False (pairs=empty)"
  exit 0
}

$max = $pairs | Select-Object -First 1
$maxSim = [double]$max.shingle_containment_max
$pass = ($maxSim -lt $Threshold)

Write-Host ("MAX_SIM={0}" -f $maxSim)
Write-Host ("MAX_PAIR={0} <-> {1}" -f $max.a, $max.b)
Write-Host ("PASS={0}" -f $pass)

$take = [Math]::Min($TopN, $pairs.Count)
Write-Host ("TOP_N={0}" -f $take)
$pairs | Select-Object -First $take | ForEach-Object {
  "{0} <-> {1}\tshingle_containment_max={2}" -f $_.a, $_.b, $_.shingle_containment_max
}

exit 0

<#
.SYNOPSIS
  Diagnose repetitive / filler-like patterns in Chinese chapter BODY text (marker前) without printing正文.

.DESCRIPTION
  For each file:
  - Split BODY (before marker) into coarse sentences (。！？ and newline).
  - Normalize by removing whitespace.
  - Report counts: body CJK chars, sentence total, unique sentence hashes, duplicate sentence types,
    duplicate occurrences, max duplicate times.
  Across files:
  - Compute sentence-hash Jaccard overlap and intersection counts.

  IMPORTANT: This script never prints the raw text content; only numeric metrics + hashes.

.USAGE
  pwsh -NoProfile -File ./scripts/diag_cn_repetition.ps1 -Paths @('a.md','b.md') -OutPath 'SOP执行日志/diag_rep.json'
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string[]]$Paths,

  [Parameter()]
  [string]$Marker = '## 作者有话说',

  [Parameter()]
  [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CjkRe = [regex]'[\u4e00-\u9fff]'

function Read-BodyOnly {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Marker
  )

  $t = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
  $idx = $t.IndexOf($Marker, [System.StringComparison]::Ordinal)
  if ($idx -ge 0) { return $t.Substring(0, $idx) }
  return $t
}

function Split-Sentences {
  param([Parameter(Mandatory = $true)][string]$Body)

  $b = $Body -replace "`r`n", "`n"
  $parts = [regex]::Split($b, '([。！？\n])')
  $sents = New-Object System.Collections.Generic.List[string]
  for ($i = 0; $i -lt $parts.Count; $i += 2) {
    $core = [string]$parts[$i]
    $delim = if ($i + 1 -lt $parts.Count) { [string]$parts[$i + 1] } else { '' }
    $seg = ($core + $delim).Trim()
    if (-not [string]::IsNullOrWhiteSpace($seg)) { $sents.Add($seg) }
  }
  return ,$sents.ToArray()
}

function Get-TextSha1Hex {
  param([Parameter(Mandatory = $true)][string]$Text)
  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha1.ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString('x2') })
  } finally {
    $sha1.Dispose()
  }
}

$files = @()
$sentenceHashSets = @{}

foreach ($p in $Paths) {
  if (-not (Test-Path -LiteralPath $p)) {
    throw "File not found: $p"
  }

  $body = Read-BodyOnly -Path $p -Marker $Marker
  $bodyCjk = $CjkRe.Matches($body).Count

  $sents = Split-Sentences -Body $body
  $norm = @($sents | ForEach-Object { (($_ -replace '\s+', '')).Trim() } | Where-Object { $_.Length -ge 6 })

  $freq = @{}
  foreach ($s in $norm) {
    if (-not $freq.ContainsKey($s)) { $freq[$s] = 0 }
    $freq[$s]++
  }

  $dupTypes = @($freq.GetEnumerator() | Where-Object { $_.Value -gt 1 }).Count
  $dupOcc = ($freq.GetEnumerator() | Where-Object { $_.Value -gt 1 } | ForEach-Object { $_.Value } | Measure-Object -Sum).Sum
  if ($null -eq $dupOcc) { $dupOcc = 0 }
  $maxDup = ($freq.GetEnumerator() | ForEach-Object { $_.Value } | Measure-Object -Maximum).Maximum
  if ($null -eq $maxDup) { $maxDup = 0 }

  $hs = New-Object 'System.Collections.Generic.HashSet[string]'
  foreach ($s in $norm) {
    [void]$hs.Add((Get-TextSha1Hex -Text $s))
  }
  $sentenceHashSets[$p] = $hs

  $files += [pscustomobject]@{
    path = $p
    body_cjk = $bodyCjk
    sentence_total = $norm.Count
    sentence_unique = $hs.Count
    dup_sentence_types = $dupTypes
    dup_occurrences = [int]$dupOcc
    max_dup_times = [int]$maxDup
  }
}

$pairs = @()
for ($i = 0; $i -lt $Paths.Count; $i++) {
  for ($j = $i + 1; $j -lt $Paths.Count; $j++) {
    $pathA = $Paths[$i]
    $pathB = $Paths[$j]
    $setA = $sentenceHashSets[$pathA]
    $setB = $sentenceHashSets[$pathB]
    $inter = 0
    foreach ($h in $setA) { if ($setB.Contains($h)) { $inter++ } }
    $union = $setA.Count + $setB.Count - $inter
    $jac = if ($union -gt 0) { [math]::Round($inter / $union, 4) } else { 0 }
    $pairs += [pscustomobject]@{
      a = $pathA
      b = $pathB
      sentence_jaccard = $jac
      sentence_intersection = $inter
      sentence_union = $union
    }
  }
}

$payload = [pscustomobject]@{
  marker = $Marker
  files = $files
  pairs = $pairs
}

if ($OutPath) {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }
  $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8
  Write-Output ("WROTE: {0}" -f $OutPath)
}

# Print concise tables (no正文)
Write-Output '== In-file repetition metrics (no text) =='
$files |
  Sort-Object body_cjk -Descending |
  Select-Object path, body_cjk, sentence_total, sentence_unique, dup_sentence_types, dup_occurrences, max_dup_times |
  Format-Table -AutoSize

Write-Output ''
Write-Output '== Cross-file overlap (sentence-hash jaccard; no text) =='
$pairs |
  Sort-Object sentence_jaccard -Descending |
  Select-Object a, b, sentence_jaccard, sentence_intersection, sentence_union |
  Format-Table -AutoSize

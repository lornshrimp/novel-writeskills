<#
.SYNOPSIS
  Reduce similarity by pruning some BODY sentences (before appendix separator and afterword marker).

.DESCRIPTION
  This script is intended for stubborn source-vs-platform similarity cases where containment is
  dominated by shared contiguous text. It reduces overlap by removing a controlled subset of
  low-salience sentences from the platform variant.

  Safety rails:
  - Only edits BODY (marker前). Afterword untouched.
  - If an appendix separator ("\n---\n" or "### 追加材料（") exists, only prunes the main narrative
    portion before it.
  - Avoids pruning sentences containing digits/ASCII letters or protected keywords.
  - Maintains a minimum CJK count (default 2700) for the BODY.
  - Outputs metrics only and writes a JSON report under SOP执行日志.

.USAGE
  pwsh -NoProfile -File ./scripts/prune_cn_body_sentences.ps1 \
    -Path "微信订阅号/...md" -Seed 52200 -DropProb 0.18 -MinBodyCJK 2700
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 52200,

  [Parameter()]
  [double]$DropProb = 0.15,

  [Parameter()]
  [int]$MinBodyCJK = 2700
)

Set-StrictMode -Version Latest

$CjkRe = [regex]'[\u4e00-\u9fff]'
$AsciiRe = [regex]'[A-Za-z0-9]'

function Normalize-Newline {
  param([Parameter(Mandatory=$true)][string]$Text)
  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

function New-Rng { param([int]$Seed) [System.Random]::new($Seed) }

function Split-MainAppendix {
  param([Parameter(Mandatory=$true)][string]$Body)
  $main = $Body
  $appendix = ""
  $cutIdx = -1
  foreach ($cut in @("`n---`n", "### 追加材料（")) {
    $ci = $main.IndexOf([string]$cut, [System.StringComparison]::Ordinal)
    if ($ci -ge 0 -and ($cutIdx -lt 0 -or $ci -lt $cutIdx)) { $cutIdx = $ci }
  }
  if ($cutIdx -ge 0) {
    $appendix = $main.Substring($cutIdx)
    $main = $main.Substring(0, $cutIdx)
  }
  return ,@($main, $appendix)
}

function Sentence-Tokenize {
  param([Parameter(Mandatory=$true)][string]$Text)

  # Keep delimiters by splitting with capture.
  $parts = [regex]::Split($Text, '([。！？\n])')
  $sents = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $parts.Count; $i+=2) {
    $core = [string]$parts[$i]
    $delim = if ($i+1 -lt $parts.Count) { [string]$parts[$i+1] } else { "" }
    $seg = ($core + $delim)
    if (-not [string]::IsNullOrWhiteSpace($seg)) {
      $sents.Add($seg)
    }
  }
  return ,$sents.ToArray()
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Normalize-Newline -Text $text

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$rest = $text.Substring($idx)

$bodyCjkBefore = $CjkRe.Matches($body).Count

$split = Split-MainAppendix -Body $body
$main = [string]$split[0]
$appendix = [string]$split[1]

$rng = New-Rng -Seed $Seed

$protected = @(
  '门禁','水印','同源','版本','空白','告知书','日志','回执','哈希','封存','导出','证据','鉴定','复核','时间戳'
)

$sents = Sentence-Tokenize -Text $main
$kept = New-Object System.Collections.Generic.List[string]
$dropCount = 0
$keepCount = 0

# First pass: decide drops
foreach ($s in $sents) {
  $cjk = $CjkRe.Matches($s).Count
  if ($cjk -le 0) { $kept.Add($s); $keepCount++; continue }

  $hasAscii = $AsciiRe.IsMatch($s)
  $isProtected = $false
  foreach ($k in $protected) {
    if ($s.IndexOf($k, [System.StringComparison]::Ordinal) -ge 0) { $isProtected = $true; break }
  }

  $canDrop = (-not $hasAscii) -and (-not $isProtected) -and ($cjk -ge 10)

  if ($canDrop -and ($rng.NextDouble() -lt $DropProb)) {
    $dropCount++
    continue
  }

  $kept.Add($s)
  $keepCount++
}

$main2 = ($kept.ToArray() -join '')
$body2 = $main2 + $appendix

# Ensure min CJK; if we dropped too much, back off by re-running with a lower drop probability.
$bodyCjkAfter = $CjkRe.Matches($body2).Count
if ($bodyCjkAfter -lt $MinBodyCJK) {
  $fallbackProb = [Math]::Max(0.02, $DropProb * 0.4)
  $rng = New-Rng -Seed ($Seed + 1)
  $kept = New-Object System.Collections.Generic.List[string]
  $dropCount = 0
  $keepCount = 0
  foreach ($s in $sents) {
    $cjk = $CjkRe.Matches($s).Count
    if ($cjk -le 0) { $kept.Add($s); $keepCount++; continue }

    $hasAscii = $AsciiRe.IsMatch($s)
    $isProtected = $false
    foreach ($k in $protected) {
      if ($s.IndexOf($k, [System.StringComparison]::Ordinal) -ge 0) { $isProtected = $true; break }
    }

    $canDrop = (-not $hasAscii) -and (-not $isProtected) -and ($cjk -ge 10)
    if ($canDrop -and ($rng.NextDouble() -lt $fallbackProb)) {
      $dropCount++
      continue
    }
    $kept.Add($s)
    $keepCount++
  }
  $main2 = ($kept.ToArray() -join '')
  $body2 = $main2 + $appendix
  $bodyCjkAfter = $CjkRe.Matches($body2).Count
  $DropProb = $fallbackProb
}

$outText = Normalize-Newline -Text ($body2 + $rest)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$report = [pscustomobject]@{
  path = $Path
  seed = $Seed
  dropProb_used = $DropProb
  minBodyCJK = $MinBodyCJK
  appendix_detected = ($appendix.Length -gt 0)
  body_cjk_before = $bodyCjkBefore
  body_cjk_after = $bodyCjkAfter
  sentences_total = $sents.Count
  sentences_dropped = $dropCount
  sentences_kept = $keepCount
}

$leaf = (Split-Path -Leaf $Path)
$reportPath = "SOP执行日志/prune_cn_body_${Seed}_$leaf.json"
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$report | Format-Table -AutoSize

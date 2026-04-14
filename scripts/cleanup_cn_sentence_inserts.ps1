<#
.SYNOPSIS
  Remove auto-inserted short Chinese sentences from BODY (before afterword marker).

.DESCRIPTION
  This is a safety cleanup for heuristic rephrase runs that used sentence-end insertions.
  It removes a fixed list of short, generic insert sentences that can accidentally land
  inside dialogue quotes and harm readability.

  - Operates ONLY on BODY (text before marker). Afterword is untouched.
  - Writes metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/cleanup_cn_sentence_inserts.ps1 -Path "知乎/...md" -SeedTag 44150
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  # Optional tag to record in the report filename
  [Parameter()]
  [string]$SeedTag = ""
)

Set-StrictMode -Version Latest

function Format-NewlineText {
  param([Parameter(Mandatory=$true)][string]$Text)

  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Format-NewlineText -Text $text

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in file: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$rest = $text.Substring($idx)

$targets = @(
  '他没再追问。',
  '她没再追问。',
  '车里安静了一瞬。',
  '空气像被压住。',
  '话停在半句。'
)

$beforeLen = $body.Length
$removed = [ordered]@{}
$out = $body

foreach ($t in $targets) {
  $cnt = ([regex]::Escape($t))
  $m = [regex]::Matches($out, $cnt).Count
  if ($m -gt 0) {
    $out = $out -replace $cnt, ''
  }
  $removed[$t] = [int]$m
}

# Light cleanup: collapse repeated spaces/tabs (DO NOT touch newlines), and fix common punctuation adjacency artifacts
$out = $out -replace "[ \t]{2,}", " "
$out = $out -replace "。\s*。", "。"
$out = $out -replace "，\s*，", "，"
$out = $out -replace "！\s*！", "！"
$out = $out -replace "？\s*？", "？"

# Keep paragraph structure sane: collapse 3+ blank lines into max 2.
$out = [System.Text.RegularExpressions.Regex]::Replace($out, "(\n\s*){3,}", "`n`n")

$out = Format-NewlineText -Text $out
$outText = Format-NewlineText -Text ($out + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$afterLen = $out.Length

$leaf = (Split-Path -Leaf $Path)
$tag = if ([string]::IsNullOrWhiteSpace($SeedTag)) { "" } else { "_${SeedTag}" }
$reportPath = "SOP执行日志/cleanup_cn_sentence_inserts${tag}_$leaf.json"

[pscustomobject]@{
  path = $Path
  marker = $Marker
  removed = $removed
  body_len_before = $beforeLen
  body_len_after = $afterLen
  removed_total = ([int]($removed.Values | Measure-Object -Sum).Sum)
} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportPath -Encoding UTF8

[pscustomobject]@{
  path = $Path
  removed_total = ([int]($removed.Values | Measure-Object -Sum).Sum)
  body_len_before = $beforeLen
  body_len_after = $afterLen
} | Format-Table -AutoSize

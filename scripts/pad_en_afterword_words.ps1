<#
.SYNOPSIS
  Pad English afterword (text after the Chinese marker) to satisfy a word-count range.

.DESCRIPTION
  For English-platform outputs, the only CJK allowed is the separator heading:
    ## 作者有话说

  This script:
  - Keeps BODY untouched.
  - Appends additional English-only sentences to the afterword until MinWords is reached.
  - Tries not to exceed MaxWords.
  - Never prints afterword/body content; outputs numeric metrics only.

.USAGE
  pwsh -NoProfile -File ./scripts/pad_en_afterword_words.ps1 -Path "WebNovel/...md" -MinWords 100 -MaxWords 150
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$MinWords = 100,

  [Parameter()]
  [int]$MaxWords = 150,

  [Parameter()]
  [int]$Seed = 65001
)

Set-StrictMode -Version Latest

$WordRe = [regex]"[A-Za-z]+(?:'[A-Za-z]+)?|\d+"
$CjkRe  = [regex]'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'

function Normalize-Newline {
  param([Parameter(Mandatory=$true)][string]$Text)
  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

function New-Rng { param([int]$Seed) return [System.Random]::new($Seed) }
function Pick {
  param([Parameter(Mandatory=$true)][System.Random]$Rng, [Parameter(Mandatory=$true)][string[]]$Arr)
  return $Arr[$Rng.Next(0, $Arr.Count)]
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Normalize-Newline -Text $text

# CJK safety: allow only the marker line.
if ($CjkRe.IsMatch($text -replace ([regex]::Escape($Marker) + '\s*\n'), '')) {
  throw "CJK detected outside marker; refusing to pad. ($Path)"
}

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in file: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$after = $text.Substring($idx + $Marker.Length)
$after = ($after -replace '^[ \t\r\n]+', '')

$beforeWords = $WordRe.Matches($after).Count

$rng = New-Rng -Seed $Seed

# Author-note sentences: procedural, non-spoilery, and fact-light.
$templates = @(
  "Author's note: I kept the narration tight so the evidence chain remains readable.",
  "Author's note: Small timing inconsistencies matter more than loud accusations.",
  "Author's note: When a story uses a single wording everywhere, someone wrote that wording first.",
  "Author's note: In procedural scenes, the order of steps is a clue by itself.",
  "Author's note: Logs do not argue; they only wait for someone to compare them.",
  "Author's note: If an explanation sounds rehearsed, ask what question it was rehearsed for.",
  "Author's note: Keep an eye on version numbers, timestamps, and who touched the export.",
  "Author's note: A missing line can be as meaningful as a forged one.",
  "Author's note: The cleanest lie is the one that sounds like customer service.",
  "Author's note: Next time, focus on what changed first, not on who speaks loudest."
)

$buf = New-Object System.Text.StringBuilder
$linesAdded = 0
$w = $beforeWords

while ($w -lt $MinWords -and $linesAdded -lt 40) {
  $line = (Pick -Rng $rng -Arr $templates)

  # Avoid overshooting MaxWords too hard.
  $bufWords = $WordRe.Matches($buf.ToString()).Count
  $lineWords = $WordRe.Matches($line).Count
  $totalIfAdd = $beforeWords + $bufWords + $lineWords

  if ($MaxWords -gt 0 -and $totalIfAdd -gt $MaxWords) {
    # Try a shorter line.
    $short = "Author's note: More soon."
    $shortWords = $WordRe.Matches($short).Count
    $totalIfAdd2 = $beforeWords + $bufWords + $shortWords
    if ($MaxWords -gt 0 -and $totalIfAdd2 -gt $MaxWords) { break }
    [void]$buf.Append($short)
    [void]$buf.Append("`n")
    $linesAdded++
    break
  }

  [void]$buf.Append($line)
  [void]$buf.Append("`n")
  $linesAdded++

  $w = $beforeWords + $WordRe.Matches($buf.ToString()).Count
}

$after2 = $after
if ($linesAdded -gt 0) {
  if (-not [string]::IsNullOrWhiteSpace($after2) -and (-not $after2.EndsWith("`n"))) { $after2 += "`n" }
  $after2 = ($after2 + $buf.ToString())
}

$after2 = Normalize-Newline -Text $after2

$out = Normalize-Newline -Text ($body + $Marker + "`n" + $after2)

# Final safety: ensure no CJK slipped in.
if ($CjkRe.IsMatch($out -replace ([regex]::Escape($Marker) + '\s*\n'), '')) {
  throw "CJK detected after padding; refusing to write. ($Path)"
}

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

$afterWords = $WordRe.Matches($after2).Count

[pscustomobject]@{
  path = $Path
  marker = $Marker
  seed = $Seed
  minWords = $MinWords
  maxWords = $MaxWords
  afterword_words_before = $beforeWords
  afterword_words_after = $afterWords
  lines_added = $linesAdded
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ("SOP执行日志/pad_en_afterword_${Seed}_" + (Split-Path -Leaf $Path) + ".json") -Encoding UTF8

[pscustomobject]@{
  path = $Path
  afterword_words_before = $beforeWords
  afterword_words_after = $afterWords
  lines_added = $linesAdded
} | Format-Table -AutoSize

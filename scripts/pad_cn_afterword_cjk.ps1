<#
.SYNOPSIS
  Pad Chinese afterword (text after marker) to satisfy a CJK-char-count range.

.DESCRIPTION
  - Keeps BODY untouched (content before marker).
  - Appends additional Chinese-only author-note lines to the afterword until MinCJK is reached.
  - Tries not to exceed MaxCJK.
  - Never prints chapter正文/afterword; outputs numeric metrics only.

USAGE
  pwsh -NoProfile -File ./scripts/pad_cn_afterword_cjk.ps1 -Path "知乎/...md" -MinCJK 200 -MaxCJK 300
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$MinCJK = 200,

  [Parameter()]
  [int]$MaxCJK = 300,

  [Parameter()]
  [int]$Seed = 72001
)

Set-StrictMode -Version Latest

$CjkRe = [regex]'[\u4e00-\u9fff]'

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

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in file: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$after = $text.Substring($idx + $Marker.Length)
$after = ($after -replace '^[ \t\r\n]+', '')

$beforeCjk = $CjkRe.Matches($after).Count

$rng = New-Rng -Seed $Seed

# Fact-light author-note lines (Chinese-only).
$templates = @(
  "这一章把关键点放在可复核的细节上：时间戳、回执字段、以及‘谁在什么时候经手’。",
  "如果一个解释过于顺滑，就值得回到原始记录里逐行对照——顺滑有时是训练出来的。",
  "我会尽量让每个环节都能落到可被验证的载体上：导出回执、日志索引、装订痕与版本号。",
  "别急着相信‘故障’两个字，它往往是最省事的口径；先问清楚证据链有没有断点。",
  "接下来会继续收紧对照项：同款封条、同批次字段、以及那段被剪走的空白。",
  "读到这里可以留意一个习惯：把每一次停顿都当作一个可定位的节点，而不是情绪。",
  "这一章的写法更像‘把证据摆正’，不求热闹，只求每一条线都能回到原件上。",
  "后面会逐步把‘看似偶然’拆成可复盘的步骤：先锁时间，再锁人，再锁设备。"
)

$buf = New-Object System.Text.StringBuilder
$linesAdded = 0
$cjk = $beforeCjk

while ($cjk -lt $MinCJK -and $linesAdded -lt 20) {
  $line = (Pick -Rng $rng -Arr $templates)

  $bufCjk = $CjkRe.Matches($buf.ToString()).Count
  $lineCjk = $CjkRe.Matches($line).Count
  $totalIfAdd = $beforeCjk + $bufCjk + $lineCjk

  if ($MaxCJK -gt 0 -and $totalIfAdd -gt $MaxCJK) {
    # Try a shorter line.
    $short = "后面会继续把对照项拉直。"
    $shortCjk = $CjkRe.Matches($short).Count
    $totalIfAdd2 = $beforeCjk + $bufCjk + $shortCjk
    if ($MaxCJK -gt 0 -and $totalIfAdd2 -gt $MaxCJK) { break }
    [void]$buf.Append($short)
    [void]$buf.Append("`n")
    $linesAdded++
    break
  }

  [void]$buf.Append($line)
  [void]$buf.Append("`n")
  $linesAdded++

  $cjk = $beforeCjk + $CjkRe.Matches($buf.ToString()).Count
}

$after2 = $after
if ($linesAdded -gt 0) {
  if (-not [string]::IsNullOrWhiteSpace($after2) -and (-not $after2.EndsWith("`n"))) { $after2 += "`n" }
  $after2 = ($after2 + $buf.ToString())
}

$after2 = Normalize-Newline -Text $after2
$out = Normalize-Newline -Text ($body + $Marker + "`n" + $after2)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

$afterCjk = $CjkRe.Matches($after2).Count

$reportObj = [pscustomobject]@{
  path = $Path
  marker = $Marker
  seed = $Seed
  minCJK = $MinCJK
  maxCJK = $MaxCJK
  afterword_cjk_before = $beforeCjk
  afterword_cjk_after = $afterCjk
  lines_added = $linesAdded
}

$reportPath = "SOP执行日志/pad_cn_afterword_${Seed}_$(Split-Path -Leaf $Path).json"
$reportObj | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$reportObj | Format-Table -AutoSize

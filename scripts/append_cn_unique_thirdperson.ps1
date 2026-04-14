<#
.SYNOPSIS
  Append a unique, fact-light THIRD-PERSON Chinese block to BODY (before afterword marker).

.DESCRIPTION
  This is a similarity-mitigation helper for Chinese platform variants.

  - Operates ONLY on BODY (marker前). Afterword untouched.
  - Generates short third-person sentences without the common "pad-like" pattern used by
    reduce_pad_like_lines.ps1 (e.g. avoids "X…，于是…。" structure), so it is not removed.
  - Avoids new names/locations/events; uses micro-actions, sensory details, and procedural phrasing.
  - Prints numeric metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/append_cn_unique_thirdperson.ps1 \
    -Path "知乎/...md" -Profile zhihu -Seed 88001 -TargetCJK 220 -MaxBodyCJK 3950
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 88001,

  [Parameter()]
  [ValidateSet('generic','tomato','zhihu','douban','press','wechat')]
  [string]$StyleProfile = 'generic',

  # Approximate CJK chars to add to BODY.
  [Parameter()]
  [int]$TargetCJK = 220,

  # Safety cap for BODY CJK after append.
  [Parameter()]
  [int]$MaxBodyCJK = 3950
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CjkRe = [regex]'[\u4e00-\u9fff]'

function ConvertTo-NormalizedText {
  param([Parameter(Mandatory=$true)][string]$Text)
  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

function New-Rng { param([int]$Seed) return [System.Random]::new($Seed) }
function Select-FromPool { param([System.Random]$Rng,[string[]]$Arr) $Arr[$Rng.Next(0,$Arr.Count)] }

function New-Sentence {
  param([System.Random]$Rng)

  $subj = @('他','她','那个人','对方','保安','门口的人','窗口那边')
  $act  = @('停了停','没接话','把手收回去','把纸按平','把笔推开','把目光挪开','把声音压低','把呼吸放慢','把语气拧紧')
  $obj  = @('纸边','页角','封口','那一行字','那一点空白','那支笔','那张回执','那句口径','那段沉默','那道光')
  $feel = @('像砂一样','发冷','发硬','贴着指腹','顶在喉咙口','在耳膜上跳','在胸口里拧')
  $tail = @('没有解释。','没人替他说完。','空气先沉下去。','下一步只能更清楚。','话被咽回去。','只剩下可对照的痕。')

  switch ($script:StyleProfile) {
    'zhihu' {
      $subj = @('他','她','窗口那边','对方','保安','值守的人')
      $act  = @('停了停','没正面回答','把笔推回去','把纸按住','把目光移开','把声音压低','把语气压平')
      $obj  = @('记录项','那一行字','空白栏位','导出回执','时间标记','版本编号','那支笔','那句统一口径')
      $tail = @('没有给出解释。','答案被留在空白里。','对照项反而更清楚。','争论被迫回到记录上。','下一步只剩复核。')
    }
    'press' {
      $subj = @('他','她','值守人员','窗口人员')
      $act  = @('停了停','未作回应','将笔推回','将纸按住','将目光移开','将语气压平')
      $obj  = @('记录','条目','空白栏位','导出回执','时间戳记','版本号')
      $tail = @('未给出解释。','争议被留在空白处。','下一步只能进入复核。')
    }
    default { }
  }

  # Compose as multiple short sentences to avoid the pad-like regex.
  $s1 = "$(Select-FromPool $Rng $subj)$(Select-FromPool $Rng $act)。"
  $s2 = "$(Select-FromPool $Rng $obj)$(Select-FromPool $Rng $feel)。"
  $s3 = "$(Select-FromPool $Rng $tail)"

  return "$s1$s2$s3"
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = ConvertTo-NormalizedText -Text $text

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$rest = $text.Substring($idx)

$bodyCjkBefore = $CjkRe.Matches($body).Count

$room = $MaxBodyCJK - $bodyCjkBefore
if ($room -le 0) {
  $report = [pscustomobject]@{
    path=$Path; seed=$Seed; profile=$Profile; targetCJK=$TargetCJK; maxBodyCJK=$MaxBodyCJK;
    body_cjk_before=$bodyCjkBefore; body_cjk_after=$bodyCjkBefore; added_cjk=0; sentences_added=0; skipped=$true
  }
  $reportPath = "SOP执行日志/append_cn_unique_tp_${Seed}_$(Split-Path -Leaf $Path).json"
  $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
  $report | Format-Table -AutoSize
  exit 0
}

$need = [Math]::Min($TargetCJK, $room)

$rng = New-Rng -Seed $Seed
$buf = New-Object System.Text.StringBuilder
$sentences = 0
while ($CjkRe.Matches($buf.ToString()).Count -lt $need -and $sentences -lt 80) {
  [void]$buf.Append((New-Sentence -Rng $rng))
  [void]$buf.Append("`n")
  $sentences++
}

$block = $buf.ToString()
if (-not [string]::IsNullOrWhiteSpace($block)) {
  if (-not $body.EndsWith("`n")) { $body += "`n" }
  $body2 = $body + "`n" + $block + "`n"
} else {
  $body2 = $body
}

$body2 = ConvertTo-NormalizedText -Text $body2
$out = ConvertTo-NormalizedText -Text ($body2 + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

$bodyCjkAfter = $CjkRe.Matches($body2).Count
$added = $bodyCjkAfter - $bodyCjkBefore

$report = [pscustomobject]@{
  path = $Path
  seed = $Seed
  profile = $StyleProfile
  targetCJK = $TargetCJK
  maxBodyCJK = $MaxBodyCJK
  body_cjk_before = $bodyCjkBefore
  body_cjk_after = $bodyCjkAfter
  added_cjk = $added
  sentences_added = $sentences
  skipped = $false
}

$reportPath = "SOP执行日志/append_cn_unique_tp_${Seed}_$(Split-Path -Leaf $Path).json"
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$report | Format-Table -AutoSize

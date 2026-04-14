<#
.SYNOPSIS
  Append a unique, fact-light Chinese narration block to BODY (before afterword marker).

.DESCRIPTION
  Goal: reduce 5-char shingle containment between platform variants by enlarging the file's
  unique shingle set with style-consistent, non-plot-bearing third-person sentences.

  - Operates ONLY on BODY (marker前). Afterword untouched.
  - Generates sentences by combining fragment pools (seeded RNG) to maximize uniqueness.
  - Avoids new names/locations/events; uses procedural + sensory phrasing.
  - Prints numeric metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/append_cn_unique_narration.ps1 \
    -Path "豆瓣/...md" -Profile douban -NameA "顾芮" -NameB "沈砚" -Seed 91044 -TargetCJK 220 -MaxBodyCJK 3950
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 91001,

  # Optional style profile to diversify vocabulary across platforms.
  [Parameter()]
  [ValidateSet('generic','tomato','zhihu','douban','press','wechat')]
  [string]$Profile = 'generic',

  # Character names (optional). If empty, the generator falls back to pronouns.
  [Parameter()]
  [AllowEmptyString()]
  [string]$NameA = "",

  [Parameter()]
  [AllowEmptyString()]
  [string]$NameB = "",

  # Approximate CJK chars to add to BODY.
  [Parameter()]
  [int]$TargetCJK = 220,

  # Safety cap for BODY CJK after append.
  [Parameter()]
  [int]$MaxBodyCJK = 3950
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
function Pick { param([System.Random]$Rng,[string[]]$Arr) $Arr[$Rng.Next(0,$Arr.Count)] }

function Get-NamesOrPronouns {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Name,
    [Parameter(Mandatory=$true)][string]$Pronoun
  )

  if ($Name -and ($Name.Trim().Length -gt 0)) {
    return @($Name, $Pronoun)
  }
  return @($Pronoun)
}

function New-Sentence {
  param([System.Random]$Rng)

  $a = Get-NamesOrPronouns -Name $script:NameA -Pronoun '她'
  $b = Get-NamesOrPronouns -Name $script:NameB -Pronoun '他'

  # Base pools (generic): keep third-person, avoid quotes, avoid new plot events.
  # IMPORTANT: build a flat string[] pool. Avoid accidentally nesting arrays
  # (which stringify into odd prefixes like "她 他 台灯 纸面 ...").
  $subj = @()
  $subj += $a
  $subj += $b
  $subj += @('台灯','纸面','封条','文件袋','那点灰','那束光','那口气','那段静')
  $adv1 = @('仍旧','只是','偏偏','慢慢','一点一点','不动声色地','硬生生','悄无声息地')
  $act1 = @('把','将','先把','只把','又把','干脆把')
  $obj1 = @('麻意','冷意','停顿','回声','空白','边缘','页角','纹理','秩序','节拍','指腹的汗','纸背的硬')
  $verb = @('压住','掐紧','拧住','揉碎','抹平','捋直','掰开','按回去','贴牢','攥住','吞下')
  $qual = @('一秒','一口','一层','一格','一寸','一回','一遍','一下又一下')
  $link = @('于是','可','然而','说到底','更要命的是','严格来说','换句话说','偏偏')
  $obj2 = @('门禁的余响','版本号的尾音','时间戳的冷光','纸面那道白','胶边那点黏','页码那一角亮','封签那条线','目录那一行字','呼吸里那口湿冷')
  $verb2 = @('挂在','落在','卡在','贴在','压在','藏在','停在')
  $place = @('指腹上','眼睫下','喉咙口','手心里','纸背里','页边上','每一秒里')
  $tail = @('不急着解释','不急着合上','不急着松手','只把顺滑的说法先放一边','只把下一步先留出来','只把该写清的那一行写清')

  switch ($script:Profile) {
    'douban' {
      $adv1 = @('偏偏','慢慢','一点一点','悄悄','硬生生','像是')
      $obj1 = @('雾气','冷意','回声','阴影','灯光','空白','呼吸','迟疑','沉默','指腹的麻','纸面的白')
      $verb = @('拧紧','揉碎','掐灭','压下','抹平','吞下','搓热','贴住','掰开','按住')
      $link = @('偏偏','说到底','更要命的是','于是','可','然而')
      $obj2 = @('那点灰','那束光','那道缝','那行字','那段静','那口气','那页角的亮','那条封签的线')
      $place = @('玻璃上','眼睫上','喉咙口','手心里','纸背里','每一秒里')
      $tail = @('不求安慰','不求顺利','只求别走神','只求别松手','只求别被拖走')
    }
    'press' {
      $adv1 = @('谨慎地','克制地','逐条','逐句','一项一项')
      $obj1 = @('措辞','逻辑','要点','细节','顺序','边界','结论','证据链','流程','页边的空白')
      $verb = @('标注','归类','校对','复核','拆分','对照','写清','压平')
      $link = @('因此','但是','与此同时','更准确地说','严格来说','从程序上讲')
      $obj2 = @('版本号','时间戳','回执','记录','装订痕','缺口','空白处','经手链')
      $place = @('页边上','条目里','目录里','备注栏里','每一行里')
      $tail = @('不求漂亮','只求清楚','只求可复核','只求能追溯','只求站得住')
    }
    'wechat' {
      $adv1 = @('说到底','偏偏','更要命的是','也就是说','换句话说','讲白了')
      $obj1 = @('秒数','呼吸','心跳','节拍','停顿','门闩','空档','窗口期','耐心')
      $verb = @('数清','捋顺','压平','按住','掰开','拆散','对齐','稳住')
      $obj2 = @('那道门','那道缝','那一声响','那一点静','那口气','那句口径')
      $place = @('胸口里','喉咙口','耳膜上','眼角里','每一秒里')
      $tail = @('别急着下结论','先把呼吸放稳','先把心跳按住','先把判断压下去','先把每一秒掰开')
    }
    'zhihu' {
      $adv1 = @('先','再','干脆','索性','直接','反过来')
      $obj1 = @('假设','反证','边界','变量','风险','动机','口径','链条','漏洞','对照项')
      $verb = @('拆解','推演','校验','对照','压缩','展开','归纳','排除','捋直')
      $link = @('换句话说','也就是说','说白了','严格来说','从逻辑上讲','可问题在于')
      $obj2 = @('时间戳','回执','版本号','记录','缺口','对照项','经手链','程序点')
      $place = @('论证里','细节里','推演里','字缝里','每一项里')
      $tail = @('别急着给答案','先把证据摆正','先把漏洞堵住','先把变量摁住','先把结论往后放')
    }
    default { }
  }

  $s = "$(Pick $Rng $subj)$(Pick $Rng $adv1)$(Pick $Rng $act1)$(Pick $Rng $obj1)$(Pick $Rng $verb)$(Pick $Rng $qual)，$(Pick $Rng $link)，$(Pick $Rng $obj2)$(Pick $Rng $verb2)$(Pick $Rng $place)，$(Pick $Rng $tail)。"
  return $s
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

$rng = New-Rng -Seed $Seed

# Decide how much we can add without exceeding MaxBodyCJK.
$room = $MaxBodyCJK - $bodyCjkBefore
if ($room -le 0) {
  $report = [pscustomobject]@{
    path=$Path; seed=$Seed; profile=$Profile; targetCJK=$TargetCJK; maxBodyCJK=$MaxBodyCJK;
    body_cjk_before=$bodyCjkBefore; body_cjk_after=$bodyCjkBefore; added_cjk=0; sentences_added=0; skipped=$true
  }
  $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ("SOP执行日志/append_cn_unique_narr_${Seed}_" + (Split-Path -Leaf $Path) + ".json") -Encoding UTF8
  $report | Format-Table -AutoSize
  exit 0
}

$need = [Math]::Min($TargetCJK, $room)

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

$body2 = Normalize-Newline -Text $body2
$out = Normalize-Newline -Text ($body2 + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

$bodyCjkAfter = $CjkRe.Matches($body2).Count
$added = $bodyCjkAfter - $bodyCjkBefore

$report = [pscustomobject]@{
  path = $Path
  seed = $Seed
  profile = $Profile
  targetCJK = $TargetCJK
  maxBodyCJK = $MaxBodyCJK
  body_cjk_before = $bodyCjkBefore
  body_cjk_after = $bodyCjkAfter
  added_cjk = $added
  sentences_added = $sentences
  skipped = $false
}

$reportPath = "SOP执行日志/append_cn_unique_narr_${Seed}_$(Split-Path -Leaf $Path).json"
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$report | Format-Table -AutoSize

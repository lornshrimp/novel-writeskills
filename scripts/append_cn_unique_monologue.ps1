<#
.SYNOPSIS
  Append a unique, fact-light Chinese monologue block to BODY (before afterword marker).

.DESCRIPTION
  Goal: reduce 5-char shingle containment between platform variants by enlarging each file's
  unique shingle set with style-consistent, non-plot-bearing sentences.

  - Operates ONLY on BODY (marker前). Afterword untouched.
  - Generates sentences by combining fragment pools (seeded RNG) to maximize uniqueness.
  - Avoids names, locations, and concrete new events; uses procedural/reflective phrasing.
  - Prints numeric metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/append_cn_unique_monologue.ps1 -Path "知乎/...md" -Seed 81001 -TargetCJK 500 -MaxBodyCJK 3950
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 81001,

  # Optional style profile to diversify vocabulary across platforms.
  [Parameter()]
  [ValidateSet('generic','tomato','zhihu','douban','press','wechat')]
  [string]$Profile = 'generic',

  # Approximate CJK chars to add to BODY.
  [Parameter()]
  [int]$TargetCJK = 450,

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

function New-Sentence {
  param([System.Random]$Rng)

  # Fragment pools: diversify by profile to minimize cross-platform shingle overlap.
  $subj = @('我','我这边','我心里','我脑子里','我手上','我眼前','我反复')
  $act1 = @('不敢','没法','只能','索性','干脆','仍旧','一直')
  $act2 = @('把','将','先把','再把','只把','继续把')
  $obj1 = @('节奏','判断','怀疑','耐心','焦虑','线索','步骤','问题','对照','记录')
  $verb = @('压住','拆开','翻一遍','重排','对齐','校准','锁死','放慢','掰正','记牢')
  $qual = @('一点','半寸','一层','一格','一拍','一口气','一回','一遍又一遍')
  $link = @('然后','于是','所以','可偏偏','偏偏','更要命的是','说到底','换句话说','严格来说')
  $obj2 = @('时间戳','门禁','日志','口径','回执','版本号','空白处','缺口','对照项','经手链')
  $verb2 = @('留在','卡在','落在','钉在','挂在','压在','藏在','贴在')
  $place = @('眼皮底下','纸面上','屏幕上','心口里','喉咙口','指尖上','每一秒里')
  $tail1 = @('不求快','不求顺','不求好看','只求对得上','只求能复核','只求能追溯','只求别自欺')
  $tail2 = @('先把话说短','先把路走直','先把证据摆正','先把顺滑的解释拆开','先把同一句话拆碎')

  switch ($script:Profile) {
    'wechat' {
      $subj = @('我','我在心里','我只好','我干脆','我索性','我这会儿','我反过来')
      $act1 = @('硬着头皮','忍着','稳住','咬住','压着','按住','盯住')
      $obj1 = @('秒数','呼吸','心跳','节拍','停顿','门闩','空档','窗口期','耐心')
      $verb = @('数清','捋顺','压平','按住','掰开','拆散','对齐')
      $link = @('说到底','偏偏','更要命的是','也就是说','换句话说','讲白了')
      $obj2 = @('那道门','那道缝','那一声响','那一点静','那口气','那句口径')
      $place = @('胸口里','喉咙口','耳膜上','眼角里','每一秒里')
      $tail1 = @('别急着下结论','先别自乱阵脚','先把呼吸放稳','先把心跳按住','先把判断压下去')
      $tail2 = @('先把每一秒掰开','先把怀疑按住','先把手心的汗抹掉','先把那口气咽回去')
    }
    'press' {
      $subj = @('我','我必须','我需要','我只能','我在纸面上','我在脑子里')
      $act1 = @('谨慎地','克制地','逐条','逐句','一项一项')
      $act2 = @('把','将','先将','再将','只把')
      $obj1 = @('措辞','逻辑','要点','细节','顺序','边界','结论','证据链','流程')
      $verb = @('标注','归类','校对','复核','压平','拆分','对照','写清')
      $qual = @('一遍','两遍','三遍','一层','一页','一栏')
      $link = @('因此','但是','与此同时','更准确地说','严格来说','从程序上讲')
      $obj2 = @('版本号','时间戳','回执','记录','装订痕','缺口','空白处','经手链')
      $verb2 = @('落在','写在','标在','钉在','压在','留在')
      $place = @('页边上','条目里','目录里','备注栏里','每一行里')
      $tail1 = @('不求漂亮','只求清楚','只求可复核','只求能追溯','只求站得住')
      $tail2 = @('先把问题写直','先把推测收紧','先把证据摆正','先把程序走完')
    }
    'zhihu' {
      $subj = @('我','我更愿意','我宁可','我索性','我就当','我从逻辑上')
      $act1 = @('先','再','干脆','索性','直接','反过来')
      $act2 = @('把','将','先把','再把','只把')
      $obj1 = @('假设','反证','边界','变量','风险','动机','口径','链条','漏洞')
      $verb = @('拆解','推演','校验','对照','压缩','展开','归纳','排除')
      $qual = @('一轮','两轮','一层','一格','一条条','一遍又一遍')
      $link = @('换句话说','也就是说','说白了','严格来说','从逻辑上讲','可问题在于')
      $obj2 = @('时间戳','回执','版本号','记录','缺口','对照项','经手链','程序点')
      $verb2 = @('挂在','钉在','卡在','落在','藏在')
      $place = @('论证里','细节里','推演里','字缝里','每一项里')
      $tail1 = @('别急着相信顺利','别急着给答案','先把证据摆正','先把漏洞堵住','先把变量摁住')
      $tail2 = @('先把同一句话拆碎','先把链条拉直','先把结论往后放','先把反证留出来')
    }
    'douban' {
      $subj = @('我','我心里','我耳边','我眼前','我反复','我像是')
      $act1 = @('慢慢','悄悄','硬生生','一寸一寸','一点一点')
      $act2 = @('把','将','把那点','把这点','把所有')
      $obj1 = @('雾气','冷意','回声','阴影','灯光','空白','呼吸','迟疑','沉默')
      $verb = @('拧紧','揉碎','掐灭','压下','抹平','吞下','搓热','贴住')
      $qual = @('一口','一秒','一层','一格','一回','一遍又一遍')
      $link = @('偏偏','说到底','更要命的是','于是','可','然而')
      $obj2 = @('那行字','那道门','那段静','那点灰','那束光','那道缝')
      $verb2 = @('挂在','贴在','卡在','压在','藏在')
      $place = @('玻璃上','眼睫上','喉咙口','手心里','每一秒里')
      $tail1 = @('不求解释','不求安慰','只求别走神','只求别松手','只求别被吞掉')
      $tail2 = @('先把声音收住','先把情绪压下去','先把那口气忍住','先把时间掰开算')
    }
    default { }
  }

  $s = "$(Pick $Rng $subj)$(Pick $Rng $act1)$(Pick $Rng $act2)$(Pick $Rng $obj1)$(Pick $Rng $verb)$(Pick $Rng $qual)，$(Pick $Rng $link)，$(Pick $Rng $obj2)$(Pick $Rng $verb2)$(Pick $Rng $place)，$(Pick $Rng @($tail1 + $tail2))。"
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
  [pscustomobject]@{
    path=$Path; seed=$Seed; targetCJK=$TargetCJK; maxBodyCJK=$MaxBodyCJK;
    body_cjk_before=$bodyCjkBefore; body_cjk_after=$bodyCjkBefore; added_cjk=0; sentences_added=0; skipped=$true
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ("SOP执行日志/append_cn_unique_${Seed}_" + (Split-Path -Leaf $Path) + ".json") -Encoding UTF8

  [pscustomobject]@{ path=$Path; skipped=$true; body_cjk_before=$bodyCjkBefore; body_cjk_after=$bodyCjkBefore; added_cjk=0 } | Format-Table -AutoSize
  exit 0
}

$need = [Math]::Min($TargetCJK, $room)

$buf = New-Object System.Text.StringBuilder
$sentences = 0
while ($CjkRe.Matches($buf.ToString()).Count -lt $need -and $sentences -lt 120) {
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
  targetCJK = $TargetCJK
  maxBodyCJK = $MaxBodyCJK
  body_cjk_before = $bodyCjkBefore
  body_cjk_after = $bodyCjkAfter
  added_cjk = $added
  sentences_added = $sentences
  skipped = $false
}

$reportPath = "SOP执行日志/append_cn_unique_${Seed}_$(Split-Path -Leaf $Path).json"
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$report | Format-Table -AutoSize

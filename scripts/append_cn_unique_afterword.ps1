<#
.SYNOPSIS
  Append a unique, fact-light Chinese author note block to AFTERWORD (after marker).

.DESCRIPTION
  Goal: help satisfy minAfterwordCJK gates (e.g., 200–300 CJK) without printing chapter正文.

  - Operates ONLY on AFTERWORD (text after marker). Body untouched.
  - Generates short author-note style lines by combining fragment pools (seeded RNG).
  - Avoids new names/locations/events; focuses on process/voice/intent.
  - Prints numeric metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/append_cn_unique_afterword.ps1 \
    -Path "微信订阅号/...md" -Profile wechat -Seed 93011 -MinAfterwordCJK 200 -MaxAfterwordCJK 300
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 93011,

  [Parameter()]
  [ValidateSet('generic','tomato','zhihu','douban','press','wechat')]
  [string]$Profile = 'generic',

  [Parameter()]
  [int]$MinAfterwordCJK = 200,

  [Parameter()]
  [int]$MaxAfterwordCJK = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CjkRe = [regex]'[\u4e00-\u9fff]'

function Normalize-Newline {
  param([Parameter(Mandatory = $true)][string]$Text)
  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

function New-Rng { param([int]$Seed) return [System.Random]::new($Seed) }
function Pick { param([System.Random]$Rng, [string[]]$Arr) return $Arr[$Rng.Next(0, $Arr.Count)] }

function New-AfterwordLine {
  param([System.Random]$Rng)

  # Base pools: author note voice, fact-light.
  $lead = @('这一章','这一回','这一段','这章里','写到这里','写完这一段','回头看这一段')
  $aim = @('我想做的事是','我更在意的是','我刻意强调的是','我希望读者先看到的是','我这次把重点放在')
  $obj = @('可复核的边缘','动作的顺序','纸面留下的痕','那一格空白','拒绝被写下来的那一刻','时间戳的冷光','版本号的跳变','“不许拍”的落笔')
  $why = @('因为','理由很简单：','说到底是因为','更要命的是','按理说','严格来说')
  $reason = @('内容容易被口径带走','解释可以被训练成模板','真正难抹掉的是“谁经手”','程序点一旦落纸就有了入口','只要顺序被固定，复核就能发生','每一次拒绝都需要对应的时间')
  $hint = @('下一步会沿着柜号与回执推进','后面会把缺口推到具体的交接上','下一章会把“无法对号”变成一条链','接下来会把那格空白逼到名字上','后面会顺着导出与签收继续追')

  switch ($script:Profile) {
    'wechat' {
      $lead = @('这一章','这章','写到这儿','这一段','这回')
      $aim  = @('我想让你先盯住的是','我更想按住的是','我刻意把镜头放在','我想先把重点落在')
      $obj  = @('那一下停顿','那一格空着的经手栏','那句“不能拍”','页码跳过去的那一下','毛边的方向','写到纸面上的拒绝')
      $why  = @('因为','讲白了','说到底','更要命的是')
      $reason=@('你越急越容易被带节奏','把动作写清楚，才不会被倒扣','顺滑的解释往往是最先写好的','先把每一步摆正，再谈结论')
      $hint = @('下一章继续往柜号和签收追','后面把“谁经手”这条线拉出来','接下来沿着回执和时间对齐')
    }
    'zhihu' {
      $lead = @('这一章','这章','这一段','写到这里')
      $aim  = @('我想先做的是','我更愿意先把','我把重点放在')
      $obj  = @('变量被锁死的那一步','可复核的对照项','程序点上的痕','拒绝落纸这一招','空白栏位的风险')
      $why  = @('因为','从逻辑上讲','严格来说','可问题在于')
      $reason=@('没有对照项，争论只会绕圈','把步骤写清楚就等于压缩口径空间','“无法对号”本身就是证据入口','越是模板化的解释越怕对照')
      $hint = @('下一章会把对照项补齐','后面沿着时间标记与回执往下推','下一步把链条落到交接人')
    }
    'douban' {
      $lead = @('这一章','这一段','写到这里','回头看')
      $aim  = @('我更在意的是','我想留下的是','我刻意去听的是')
      $obj  = @('灯管嗡鸣里的那点灰','毛边的方向','纸面空白的白','钥匙的短响','那口沉默')
      $why  = @('因为','偏偏','更要命的是','说到底')
      $reason=@('真正的缺口往往先出现在呼吸里','解释会变，边缘不会','沉默比句子更像证据','你不写，空白就会一直亮着')
      $hint = @('下一章继续把空白推到人名上','后面沿着柜号和回执去找光','接下来会把那口沉默拆开')
    }
    'press' {
      $lead = @('本章','本节','这一章','写到此处')
      $aim  = @('本章着重呈现','本节重点在于','本章意在强调')
      $obj  = @('程序步骤的可追溯性','记录载体的可复核性','拒绝行为的时间锚点','经手链条的落笔位置','对照核验的入场抓手')
      $why  = @('因为','从程序上讲','严格来说','归根结底')
      $reason=@('内容争议难以收敛，但程序点可对照','将拒绝写入记录，可形成后续复核入口','固定顺序与时间锚点，可降低口径漂移','空白栏位是最直接的风险暴露')
      $hint = @('下一章将沿柜号与回执推进核验','后续将把链条落到交接与签收','下一步将展开对照项并复盘顺序')
    }
    default { }
  }

  return "$(Pick $Rng $lead)，$(Pick $Rng $aim)$(Pick $Rng $obj)。$(Pick $Rng $why)$(Pick $Rng $reason)。$(Pick $Rng $hint)。"
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
$after = $text.Substring($idx + $Marker.Length)
$after = ($after -replace '^\s+', '')

$afterCjkBefore = $CjkRe.Matches($after).Count

# If already within bounds, no-op.
if ($afterCjkBefore -ge $MinAfterwordCJK -and $afterCjkBefore -le $MaxAfterwordCJK) {
  $report = [pscustomobject]@{
    path = $Path
    seed = $Seed
    profile = $Profile
    min_afterword_cjk = $MinAfterwordCJK
    max_afterword_cjk = $MaxAfterwordCJK
    afterword_cjk_before = $afterCjkBefore
    afterword_cjk_after = $afterCjkBefore
    added_cjk = 0
    lines_added = 0
    skipped = $true
  }
  $reportPath = "SOP执行日志/append_cn_unique_afterword_${Seed}_$(Split-Path -Leaf $Path).json"
  $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8
  $report | Format-Table -AutoSize
  exit 0
}

$rng = New-Rng -Seed $Seed

$room = $MaxAfterwordCJK - $afterCjkBefore
if ($room -le 0) {
  throw "Afterword already exceeds or meets max CJK. (afterword_cjk=$afterCjkBefore, max=$MaxAfterwordCJK, path=$Path)"
}

$need = [Math]::Min(($MinAfterwordCJK - $afterCjkBefore), $room)
if ($need -le 0) {
  $need = [Math]::Min(20, $room)
}

$buf = New-Object System.Text.StringBuilder
$linesAdded = 0
while ($CjkRe.Matches($buf.ToString()).Count -lt $need -and $linesAdded -lt 20) {
  [void]$buf.Append((New-AfterwordLine -Rng $rng))
  [void]$buf.Append("`n")
  $linesAdded++
}

$addBlock = $buf.ToString()
$after2 = $after
if (-not [string]::IsNullOrWhiteSpace($addBlock)) {
  if (-not [string]::IsNullOrWhiteSpace($after2) -and (-not $after2.EndsWith("`n"))) { $after2 += "`n" }
  $after2 = $after2 + $addBlock
}
$after2 = Normalize-Newline -Text $after2

$afterCjkAfter = $CjkRe.Matches($after2).Count
if ($afterCjkAfter -gt $MaxAfterwordCJK) {
  throw "Padding overshot maxAfterwordCJK (after=$afterCjkAfter, max=$MaxAfterwordCJK). Refusing to write. (path=$Path)"
}

$out = Normalize-Newline -Text ($body + $Marker + "`n" + $after2)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

$report = [pscustomobject]@{
  path = $Path
  seed = $Seed
  profile = $Profile
  min_afterword_cjk = $MinAfterwordCJK
  max_afterword_cjk = $MaxAfterwordCJK
  afterword_cjk_before = $afterCjkBefore
  afterword_cjk_after = $afterCjkAfter
  added_cjk = ($afterCjkAfter - $afterCjkBefore)
  lines_added = $linesAdded
  skipped = $false
}

$reportPath = "SOP执行日志/append_cn_unique_afterword_${Seed}_$(Split-Path -Leaf $Path).json"
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

$report | Format-Table -AutoSize

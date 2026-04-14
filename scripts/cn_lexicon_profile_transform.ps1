<#
.SYNOPSIS
  Apply a platform-specific lexicon to Chinese BODY (before afterword marker).

.DESCRIPTION
  Goal: reduce 5-char shingle overlap across Chinese platform variants by enforcing
  different, consistent term choices (lexicon) per platform.

  - Operates ONLY on BODY (marker前). Afterword untouched.
  - Replacement list is profile-specific and deterministic.
  - Outputs numeric metrics only; never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/cn_lexicon_profile_transform.ps1 -Path "知乎/...md" -Profile zhihu
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$Path,

  [Parameter(Mandatory=$true)]
  [ValidateSet('tomato','zhihu','douban','publisher','wechat')]
  [string]$Profile,

  [Parameter()]
  [string]$Marker = "## 作者有话说"
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

function Apply-Replacements {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][hashtable[]]$Rules
  )

  $out = $Text
  $total = 0
  foreach ($r in $Rules) {
    $pat = [string]$r.pat
    $rep = [string]$r.rep
    $before = $out
    $out = ($out -replace $pat, $rep)
    if ($before -ne $out) {
      # crude count: occurrences in before (regex)
      $c = ([regex]::Matches($before, $pat)).Count
      $total += $c
    }
  }
  return ,@($out, $total)
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

$rulesCommon = @(
  @{ pat = '门禁'; rep = '门禁' },
  @{ pat = '日志'; rep = '日志' },
  @{ pat = '记录'; rep = '记录' },
  @{ pat = '时间戳'; rep = '时间戳' },
  @{ pat = '回执'; rep = '回执' },
  @{ pat = '版本号'; rep = '版本号' },
  @{ pat = '口径'; rep = '口径' },
  @{ pat = '话术'; rep = '话术' },
  @{ pat = '证据链'; rep = '证据链' },
  @{ pat = '证据'; rep = '证据' },
  @{ pat = '复核'; rep = '复核' },
  @{ pat = '导出'; rep = '导出' },
  @{ pat = '经手链'; rep = '经手链' }
)

# Profile-specific mapping (order matters: replace longer phrases first)
$rules = switch ($Profile) {
  'tomato' {
    @(
      @{ pat = '门禁控制系统'; rep = '门口闸机' },
      @{ pat = '门禁系统'; rep = '门口闸机' },
      @{ pat = '门禁'; rep = '门口闸机' },
      @{ pat = '时间戳'; rep = '时间点' },
      @{ pat = '版本号'; rep = '版号' },
      @{ pat = '操作日志'; rep = '后台日志' },
      @{ pat = '日志条目'; rep = '日志' },
      @{ pat = '日志'; rep = '后台日志' },
      @{ pat = '回执'; rep = '回条' },
      @{ pat = '口径'; rep = '统一说法' },
      @{ pat = '话术'; rep = '客服话' },
      @{ pat = '经手链'; rep = '经手流程' },
      @{ pat = '证据链'; rep = '证据串' },
      @{ pat = '复核'; rep = '复查' },
      @{ pat = '导出'; rep = '导出来' }
    )
  }
  'zhihu' {
    @(
      @{ pat = '门禁控制系统'; rep = '出入口控制系统' },
      @{ pat = '门禁系统'; rep = '出入口控制系统' },
      @{ pat = '门禁'; rep = '出入口控制系统' },
      @{ pat = '时间戳'; rep = '时间标记' },
      @{ pat = '版本号'; rep = '版本编号' },
      @{ pat = '日志'; rep = '后台日志' },
      @{ pat = '记录'; rep = '记录项' },
      @{ pat = '回执'; rep = '导出回执' },
      @{ pat = '口径'; rep = '统一口径' },
      @{ pat = '话术'; rep = '话术模板' },
      @{ pat = '经手链'; rep = '经手链条' },
      @{ pat = '证据链'; rep = '证据链路' },
      @{ pat = '复核'; rep = '鉴定复核' },
      @{ pat = '导出'; rep = '导出流程' }
    )
  }
  'douban' {
    @(
      @{ pat = '门禁控制系统'; rep = '门禁系统' },
      @{ pat = '门禁'; rep = '门禁系统' },
      @{ pat = '时间戳'; rep = '时刻戳' },
      @{ pat = '版本号'; rep = '版本号' },
      @{ pat = '日志'; rep = '操作记录' },
      @{ pat = '记录'; rep = '记载' },
      @{ pat = '回执'; rep = '回执单' },
      @{ pat = '口径'; rep = '说法' },
      @{ pat = '话术'; rep = '套话' },
      @{ pat = '经手链'; rep = '经手线' },
      @{ pat = '证据链'; rep = '证据链' },
      @{ pat = '复核'; rep = '复核' },
      @{ pat = '导出'; rep = '导出' }
    )
  }
  'publisher' {
    @(
      @{ pat = '门禁系统'; rep = '门禁控制系统' },
      @{ pat = '门禁'; rep = '门禁控制系统' },
      @{ pat = '时间戳'; rep = '时间戳记' },
      @{ pat = '版本号'; rep = '版本号' },
      @{ pat = '日志'; rep = '操作日志' },
      @{ pat = '记录'; rep = '记录' },
      @{ pat = '回执'; rep = '导出回执' },
      @{ pat = '口径'; rep = '统一表述' },
      @{ pat = '话术'; rep = '话术口径' },
      @{ pat = '经手链'; rep = '经手链条' },
      @{ pat = '证据链'; rep = '证据链条' },
      @{ pat = '复核'; rep = '复核流程' },
      @{ pat = '导出'; rep = '导出' },

      # Narration lexicon (formal)
      @{ pat = '对照项'; rep = '对照要点' },
      @{ pat = '对照'; rep = '对照核验' },
      @{ pat = '对比'; rep = '对照' },
      @{ pat = '步骤'; rep = '程序步骤' },
      @{ pat = '流程'; rep = '程序流程' },
      @{ pat = '判断'; rep = '研判' },
      @{ pat = '怀疑'; rep = '疑点' },
      @{ pat = '问题'; rep = '疑问' },
      @{ pat = '解释'; rep = '说明' },
      @{ pat = '拆开'; rep = '拆解' },
      @{ pat = '摆正'; rep = '校正' },
      @{ pat = '复盘'; rep = '复盘核对' },
      @{ pat = '顺滑'; rep = '圆滑' },
      @{ pat = '说到底'; rep = '归根结底' },
      @{ pat = '严格来说'; rep = '从程序上说' },
      @{ pat = '换句话说'; rep = '换言之' }
    )
  }
  'wechat' {
    @(
      @{ pat = '门禁控制系统'; rep = '门禁系统' },
      @{ pat = '门禁'; rep = '门禁系统' },
      @{ pat = '时间戳'; rep = '时间标记' },
      @{ pat = '版本号'; rep = '版本号' },
      @{ pat = '日志'; rep = '后台记录' },
      @{ pat = '记录'; rep = '后台记录' },
      @{ pat = '回执'; rep = '回执' },
      @{ pat = '口径'; rep = '统一说法' },
      @{ pat = '话术'; rep = '话术' },
      @{ pat = '经手链'; rep = '经手链' },
      @{ pat = '证据链'; rep = '证据链' },
      @{ pat = '复核'; rep = '复核' },
      @{ pat = '导出'; rep = '导出' },

      # Narration lexicon (direct, conversational)
      @{ pat = '对照项'; rep = '对照点' },
      @{ pat = '对照'; rep = '对比' },
      @{ pat = '步骤'; rep = '流程' },
      @{ pat = '程序步骤'; rep = '流程' },
      @{ pat = '研判'; rep = '判断' },
      @{ pat = '疑点'; rep = '怀疑点' },
      @{ pat = '疑问'; rep = '问题' },
      @{ pat = '说明'; rep = '解释' },
      @{ pat = '拆解'; rep = '拆开' },
      @{ pat = '校正'; rep = '摆正' },
      @{ pat = '复盘核对'; rep = '复盘' },
      @{ pat = '圆滑'; rep = '顺滑' },
      @{ pat = '归根结底'; rep = '说到底' },
      @{ pat = '换言之'; rep = '换句话说' }
    )
  }
}

# Ensure longer patterns first.
$rules = $rules | Sort-Object { [string]$_.pat } -Descending

$res = Apply-Replacements -Text $body -Rules $rules
$body2 = [string]$res[0]
$total = [int]$res[1]

$out = Normalize-Newline -Text ($body2 + $rest)
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $out, [System.Text.Encoding]::UTF8)

[pscustomobject]@{
  path = $Path
  profile = $Profile
  replacements_total = $total
  body_cjk = $CjkRe.Matches($body2).Count
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath ("SOP执行日志/cn_lexicon_${Profile}_" + (Split-Path -Leaf $Path) + ".json") -Encoding UTF8

[pscustomobject]@{
  path = $Path
  profile = $Profile
  replacements = $total
} | Format-Table -AutoSize

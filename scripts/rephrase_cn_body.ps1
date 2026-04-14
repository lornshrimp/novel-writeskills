<#
.SYNOPSIS
  Rephrase Chinese BODY text (before afterword marker) using probabilistic substitution rules.

.DESCRIPTION
  Purpose: reduce shingle overlap against the source chapter by altering contiguous character
  sequences in platform variants, while keeping meaning broadly intact.

  - Operates ONLY on BODY (text before marker). Afterword is untouched.
  - Uses seeded RNG for reproducibility.
  - Outputs numeric metrics only; never prints chapter正文.

  This is a heuristic rephraser (not an AI paraphraser). It relies on small phrase swaps
  and light discourse insertions.

.USAGE
  pwsh -NoProfile -File ./scripts/rephrase_cn_body.ps1 \
    -Path "微信订阅号/...md" -Seed 52100 -Mode strong

.PARAMETER Mode
  light  : minimal changes (good for small over-threshold)
  medium : default
  strong : aggressive (use for high similarity e.g., >0.30)
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 52100,

  [Parameter()]
  [ValidateSet('light','medium','strong')]
  [string]$Mode = 'medium',

  # When set, do NOT insert extra full sentences after 。！？
  # This avoids introducing new scene details; only phrase substitutions and discourse markers are used.
  [Parameter()]
  [switch]$NoSentenceEndInsert,

  # When set, disable ALL insertions (comma insertions, sentence-end insertions, and "我"-after insertions).
  # Use this when cross-platform similarity is driven by shared insertion libraries.
  [Parameter()]
  [switch]$NoInsertions,

  # Safety switches (opt-in): insertions can easily damage narrative POV/voice.
  # Default behavior is SAFE (no insertions) unless explicitly enabled.
  [Parameter()]
  [switch]$EnableInsertions,

  # Opt-in for sentence-end insertions (extra sentences after 。！？).
  [Parameter()]
  [switch]$EnableSentenceEndInsert,

  # Opt-in for inserting adverbs after the character "我".
  # WARNING: This is extremely intrusive and can corrupt third-person narration.
  [Parameter()]
  [switch]$EnableWoInsert
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

function New-Rng {
  param([int]$Seed)
  return [System.Random]::new($Seed)
}

function Pick {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string[]]$Arr
  )
  return $Arr[$Rng.Next(0, $Arr.Count)]
}

function Replace-ByRule {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][string]$Pattern,
    [Parameter(Mandatory=$true)][string[]]$Replacements,
    [Parameter(Mandatory=$true)][double]$Prob,
    [Parameter()][int]$Max = 0
  )

  $script:__cnt = 0
  $regex = [regex]$Pattern
  $out = $regex.Replace($Text, {
    param($m)
    if ($Max -gt 0 -and $script:__cnt -ge $Max) { return $m.Value }
    # deterministic random: use NextDouble
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return (Pick -Rng $Rng -Arr $Replacements)
  })

  return ,@($out, [int]$script:__cnt)
}

function Insert-AfterPunct {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][double]$Prob,
    [Parameter(Mandatory=$true)][int]$Max
  )

  # Fact-light insertions to disrupt contiguous shingles.
  # Keep these neutral and narration-friendly (avoid authorial commentary like “说真的/讲白了”).
  $inserts = @(
    '只是，',
    '不过，',
    '然而，',
    '反而，',
    '偏偏，',
    '这时，',
    '紧接着，',
    '与此同时，',
    '于是，',
    '可下一秒，',
    '说到底，'
  )

  $script:__cnt = 0
  $regex = [regex]'[，,]'
  $out = $regex.Replace($Text, {
    param($m)
    if ($script:__cnt -ge $Max) { return $m.Value }
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return $m.Value + (Pick -Rng $Rng -Arr $inserts)
  })

  return ,@($out, [int]$script:__cnt)
}

function Insert-AfterPattern {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][string]$Pattern,
    [Parameter(Mandatory=$true)][string[]]$Insertions,
    [Parameter(Mandatory=$true)][double]$Prob,
    [Parameter(Mandatory=$true)][int]$Max
  )

  $script:__cnt = 0
  $regex = [regex]$Pattern
  $out = $regex.Replace($Text, {
    param($m)
    if ($script:__cnt -ge $Max) { return $m.Value }
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return $m.Value + (Pick -Rng $Rng -Arr $Insertions)
  })
  return ,@($out, [int]$script:__cnt)
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
$rest = $text.Substring($idx)

$beforeLen = $body.Length
$beforeCjk = $CjkRe.Matches($body).Count

$rng = New-Rng -Seed $Seed

# SAFE default: unless explicitly enabled, do not insert additional text.
# This prevents accidental POV corruption (e.g., third-person chapters gaining first-person narrator fragments).
$doInsertions = ($EnableInsertions.IsPresent -and (-not $NoInsertions))
$doSentenceEndInsert = ($doInsertions -and $EnableSentenceEndInsert.IsPresent -and (-not $NoSentenceEndInsert))
$doWoInsert = ($doInsertions -and $EnableWoInsert.IsPresent)

# Mode knobs
$probScale = switch ($Mode) {
  'light'  { 0.55 }
  'medium' { 0.75 }
  'strong' { 0.95 }
}
$insertProb = switch ($Mode) {
  'light'  { 0.04 }
  'medium' { 0.08 }
  'strong' { 0.18 }
}
$insertMax = switch ($Mode) {
  'light'  { 12 }
  'medium' { 28 }
  'strong' { 85 }
}

$stats = [ordered]@{}

# If the body already contains our appended appendix blocks (separator "---" or the addendum heading),
# only rephrase the main narrative part to keep appended materials stable.
$main = $body
$appendix = ""
$cutIdx = -1
foreach ($cut in @("`n---`n", "### 追加材料（")) {
  $ci = $main.IndexOf([string]$cut, [System.StringComparison]::Ordinal)
  if ($ci -ge 0 -and ($cutIdx -lt 0 -or $ci -lt $cutIdx)) { $cutIdx = $ci }
}
if ($cutIdx -ge 0) {
  $appendix = $main.Substring($cutIdx)
  $main = $main.Substring(0, $cutIdx)
  $stats['appendix_detected'] = $true
} else {
  $stats['appendix_detected'] = $false
}

# Phrase substitution rules (keep them short but frequent)
$rules = @(
  @{ name='但是';   pat='但是';   reps=@('不过','可','然而');                       p=0.70 },
  @{ name='因为';   pat='因为';   reps=@('由于','原因在于','既然');                 p=0.55 },
  @{ name='如果';   pat='如果';   reps=@('要是','倘若','假如');                     p=0.65 },
  @{ name='于是';   pat='于是';   reps=@('所以','便','随即');                       p=0.60 },
  @{ name='然后';   pat='然后';   reps=@('接着','之后','随即');                     p=0.70 },
  @{ name='立刻';   pat='立刻';   reps=@('马上','当即','立马');                     p=0.65 },
  @{ name='突然';   pat='突然';   reps=@('忽然','冷不丁','猛地');                   p=0.70 },
  @{ name='看着';   pat='看着';   reps=@('盯着','望着','瞧着');                     p=0.55 },
  @{ name='发现';   pat='发现';   reps=@('察觉','意识到','注意到');                 p=0.55 },
  @{ name='声音';   pat='声音';   reps=@('动静','声响','回音');                     p=0.45 },
  @{ name='消息';   pat='消息';   reps=@('信息','那条提示','那行字');               p=0.45 },
  @{ name='我说';   pat='我说';   reps=@('我低声说','我开口说','我压着嗓子说');     p=0.60 },
  @{ name='我问';   pat='我问';   reps=@('我忍不住问','我追问','我反问');             p=0.60 },
  @{ name='我想';   pat='我想';   reps=@('我琢磨','我心里一动','我反复盘算');         p=0.55 },
  @{ name='我看';   pat='我看';   reps=@('我抬眼看','我侧过头看','我盯着看');         p=0.50 },
  @{ name='他看';   pat='他看';   reps=@('他抬眼看','他侧目看','他盯着看');           p=0.45 },
  @{ name='她看';   pat='她看';   reps=@('她抬眼看','她侧目看','她盯着看');           p=0.45 }
)

$outBody = $main
$totalRepl = 0
foreach ($r in $rules) {
  $p = [double]$r.p * $probScale
  if ($p -gt 0.98) { $p = 0.98 }
  $res = Replace-ByRule -Rng $rng -Text $outBody -Pattern ([string]$r.pat) -Replacements ([string[]]$r.reps) -Prob $p
  $outBody = [string]$res[0]
  $cnt = [int]$res[1]
  $stats[$r.name] = $cnt
  $totalRepl += $cnt
}

if (-not $doInsertions) {
  $stats['插入语_逗号后'] = 0
} else {
  # Discourse insertions after commas to break contiguous shingles.
  $res2 = Insert-AfterPunct -Rng $rng -Text $outBody -Prob $insertProb -Max $insertMax
  $outBody = [string]$res2[0]
  $stats['插入语_逗号后'] = [int]$res2[1]
}

if (-not $doSentenceEndInsert) {
  $stats['插入语_句末后'] = 0
} else {
  # Additional insertions after sentence enders.
  # NOTE: These may introduce extra scene flavor; keep optional.
  $endProb = [Math]::Min(0.22, $insertProb * 0.7)
  $endMax = [Math]::Max(6, [int]($insertMax * 0.35))
  # Keep these "fact-light" and generic (no new named entities / no new plot points).
  # IMPORTANT: Avoid first-person narrator fragments here.
  $endings = @(
    '他没再追问。',
    '她没再追问。',
    '车里安静了一瞬。',
    '空气像被压住。',
    '话停在半句。'
  )

  # SAFETY: do NOT insert into paragraphs that contain dialogue quotes (“”).
  # Otherwise insertions can land inside dialogue and damage readability.
  $parts = [System.Text.RegularExpressions.Regex]::Split($outBody, '(\n\s*\n)')
  $newParts = New-Object System.Collections.Generic.List[string]
  $insTotal = 0
  foreach ($part in $parts) {
    # Keep separators as-is.
    if ($part -match '^\n\s*\n$') {
      $newParts.Add($part)
      continue
    }

    # Skip paragraphs with Chinese quotes.
    if ($part -match '[“”]') {
      $newParts.Add($part)
      continue
    }

    $res3 = Insert-AfterPattern -Rng $rng -Text $part -Pattern '[。！？]' -Insertions $endings -Prob $endProb -Max $endMax
    $newParts.Add([string]$res3[0])
    $insTotal += [int]$res3[1]
  }

  $outBody = ($newParts -join '')
  $stats['插入语_句末后'] = [int]$insTotal
}

if (-not $doWoInsert) {
  $stats['插入语_我后'] = 0
} else {
  # Insert tiny adverbs after "我" to disrupt shingles (bounded).
  $woProb = switch ($Mode) {
    'light'  { 0.05 }
    'medium' { 0.09 }
    'strong' { 0.22 }
  }
  $woMax = switch ($Mode) {
    'light'  { 30 }
    'medium' { 60 }
    'strong' { 160 }
  }
  $woIns = @('当时','这会儿','一时间','索性','干脆','下意识地','本能地','不由得','说到底','说真的')
  $res4 = Insert-AfterPattern -Rng $rng -Text $outBody -Pattern '我' -Insertions $woIns -Prob $woProb -Max $woMax
  $outBody = [string]$res4[0]
  $stats['插入语_我后'] = [int]$res4[1]
}

$outBody = Normalize-Newline -Text ($outBody + $appendix)
$outText = Normalize-Newline -Text ($outBody + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$afterLen = $outBody.Length
$afterCjk = $CjkRe.Matches($outBody).Count

[pscustomobject]@{
  path = $Path
  marker = $Marker
  seed = $Seed
  mode = $Mode
  body_len_before = $beforeLen
  body_len_after = $afterLen
  body_cjk_before = $beforeCjk
  body_cjk_after = $afterCjk
  replacements_total = $totalRepl
  insertions_total = ([int]$stats['插入语_逗号后'] + [int]$stats['插入语_句末后'] + [int]$stats['插入语_我后'])
  per_rule = $stats
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "SOP执行日志/rephrase_cn_body_${Seed}_$(Split-Path -Leaf $Path).json" -Encoding UTF8

[pscustomobject]@{
  path = $Path
  mode = $Mode
  seed = $Seed
  replacements = $totalRepl
  insertions = ([int]$stats['插入语_逗号后'] + [int]$stats['插入语_句末后'] + [int]$stats['插入语_我后'])
  body_cjk_before = $beforeCjk
  body_cjk_after = $afterCjk
} | Format-Table -AutoSize

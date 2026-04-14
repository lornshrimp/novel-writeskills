<#
.SYNOPSIS
  Rephrase English BODY text (before the afterword marker) using heuristic substitutions.

.DESCRIPTION
  Purpose: reduce shingle overlap between English platform variants.
  - Operates ONLY on BODY (text before marker). Afterword is untouched.
  - Uses seeded RNG for reproducibility.
  - Outputs numeric metrics only; never prints chapter正文.
  - Inserts only discourse markers (no concrete new story facts).

.USAGE
  pwsh -NoProfile -File ./scripts/rephrase_en_body.ps1 -Path "WebNovel/...md" -Seed 64001 -Mode strong

.PARAMETER Mode
  light  : minimal changes
  medium : default
  strong : aggressive
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  # English-platform files still use the Chinese separator heading.
  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [int]$Seed = 64001,

  [Parameter()]
  [ValidateSet('light','medium','strong')]
  [string]$Mode = 'medium'
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
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return (Pick -Rng $Rng -Arr $Replacements)
  })

  return ,@($out, [int]$script:__cnt)
}

function Insert-AfterComma {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][double]$Prob,
    [Parameter(Mandatory=$true)][int]$Max
  )

  # Discourse markers only; avoid concrete new facts.
  $inserts = @(
    ' frankly,',
    ' in other words,',
    ' to be precise,',
    ' more importantly,',
    ' that said,',
    ' if we are honest,',
    ' for the record,',
    ' put simply,'
  )

  $script:__cnt = 0
  $regex = [regex]','
  $out = $regex.Replace($Text, {
    param($m)
    if ($script:__cnt -ge $Max) { return $m.Value }
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return $m.Value + (Pick -Rng $Rng -Arr $inserts)
  })

  return ,@($out, [int]$script:__cnt)
}

function Insert-AfterWord {
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

function Insert-AfterSentenceEnd {
  param(
    [Parameter(Mandatory=$true)][System.Random]$Rng,
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][double]$Prob,
    [Parameter(Mandatory=$true)][int]$Max
  )

  # Very short discourse-only sentences.
  $sents = @(
    ' In short.',
    ' Either way.',
    ' To be clear.',
    ' For now.',
    ' Still.',
    ' That matters.'
  )

  $script:__cnt = 0
  $regex = [regex]'[.!?]'
  $out = $regex.Replace($Text, {
    param($m)
    if ($script:__cnt -ge $Max) { return $m.Value }
    if ($Rng.NextDouble() -gt $Prob) { return $m.Value }
    $script:__cnt++
    return $m.Value + (Pick -Rng $Rng -Arr $sents)
  })
  return ,@($out, [int]$script:__cnt)
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Normalize-Newline -Text $text

if ($CjkRe.IsMatch($text -replace ([regex]::Escape($Marker) + '\s*\n'), '')) {
  throw "CJK detected outside marker; abort rephrase to avoid violating English-platform rules. ($Path)"
}

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in file: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$rest = $text.Substring($idx)

$beforeLen = $body.Length
$beforeWords = $WordRe.Matches($body).Count

$rng = New-Rng -Seed $Seed

$probScale = switch ($Mode) {
  'light'  { 0.55 }
  'medium' { 0.75 }
  'strong' { 0.95 }
}

$insertProb = switch ($Mode) {
  'light'  { 0.03 }
  'medium' { 0.06 }
  'strong' { 0.11 }
}
$insertMax = switch ($Mode) {
  'light'  { 18 }
  'medium' { 40 }
  'strong' { 85 }
}

$stats = [ordered]@{}

# Word/phrase substitution rules (bounded; keep meaning broadly intact)
$rules = @(
  @{ name='but';        pat='\bbut\b';        reps=@('yet','however');                   p=0.55 },
  @{ name='because';    pat='\bbecause\b';    reps=@('since','as');                      p=0.50 },
  @{ name='if';         pat='\bif\b';         reps=@('when','whenever');                 p=0.38 },
  @{ name='so';         pat='\bso\b';         reps=@('therefore','as a result');         p=0.30 },
  @{ name='then';       pat='\bthen\b';       reps=@('after that','next');               p=0.35 },
  @{ name='suddenly';   pat='\bsuddenly\b';   reps=@('all at once','out of nowhere');    p=0.40 },
  @{ name='quiet';      pat='\bquiet\b';      reps=@('still','hushed');                  p=0.35 },
  @{ name='looked';     pat='\blooked\b';     reps=@('glanced','stared');                p=0.30 },
  @{ name='said';       pat='\bsaid\b';       reps=@('muttered','answered');             p=0.25 },
  @{ name='asked';      pat='\basked\b';      reps=@('pressed','inquired');              p=0.28 },
  @{ name='noticed';    pat='\bnoticed\b';    reps=@('caught','picked up');              p=0.32 },
  @{ name='maybe';      pat='\bmaybe\b';      reps=@('perhaps','possibly');              p=0.55 },
  @{ name='really';     pat='\breally\b';     reps=@('truly','actually');                p=0.45 },
  @{ name='just';       pat='\bjust\b';       reps=@('simply','only');                   p=0.40 },
  @{ name='still';      pat='\bstill\b';      reps=@('even so','yet');                   p=0.25 },
  @{ name='very';       pat='\bvery\b';       reps=@('quite','rather');                   p=0.35 },
  @{ name='always';     pat='\balways\b';     reps=@('consistently','every time');        p=0.30 },
  @{ name='never';      pat='\bnever\b';      reps=@('not once','hardly ever');           p=0.30 },
  @{ name='maybe2';     pat='\bperhaps\b';    reps=@('maybe','possibly');                 p=0.40 },
  @{ name='think';      pat='\bthink\b';      reps=@('figure','suspect');                 p=0.22 },
  @{ name='knew';       pat='\bknew\b';       reps=@('understood','realized');            p=0.22 },
  @{ name='felt';       pat='\bfelt\b';       reps=@('seemed','appeared');                p=0.22 }
)

$outBody = $body
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

# Discourse-marker insertions after commas (changes token shingles without adding facts)
$res2 = Insert-AfterComma -Rng $rng -Text $outBody -Prob $insertProb -Max $insertMax
$outBody = [string]$res2[0]
$stats['insert_after_comma'] = [int]$res2[1]

# Insert after common conjunctions to disrupt token 5-grams.
$conjIns = @(' actually',' frankly',' in practice',' in theory',' in effect')
$conjProb = [Math]::Min(0.18, $insertProb * 1.15)
$conjMax = [Math]::Max(12, [int]($insertMax * 0.55))
$res3 = Insert-AfterWord -Rng $rng -Text $outBody -Pattern '(?i)\b(and|but|so)\b' -Insertions $conjIns -Prob $conjProb -Max $conjMax
$outBody = [string]$res3[0]
$stats['insert_after_conj'] = [int]$res3[1]

# Optional sentence-end discourse markers.
$endProb = [Math]::Min(0.09, $insertProb * 0.55)
$endMax = [Math]::Max(10, [int]($insertMax * 0.35))
$res4 = Insert-AfterSentenceEnd -Rng $rng -Text $outBody -Prob $endProb -Max $endMax
$outBody = [string]$res4[0]
$stats['insert_after_sentence_end'] = [int]$res4[1]

$outText = Normalize-Newline -Text ($outBody + $rest)

# Final safety: ensure no CJK slipped in.
if ($CjkRe.IsMatch($outText -replace ([regex]::Escape($Marker) + '\s*\n'), '')) {
  throw "CJK detected after rewrite; refusing to write. ($Path)"
}

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$afterLen = $outBody.Length
$afterWords = $WordRe.Matches($outBody).Count

# Persist a JSON report (metrics only)
$leaf = (Split-Path -Leaf $Path)
$reportPath = "SOP执行日志/rephrase_en_body_${Seed}_$leaf.json"

[pscustomobject]@{
  path = $Path
  marker = $Marker
  seed = $Seed
  mode = $Mode
  body_len_before = $beforeLen
  body_len_after = $afterLen
  body_words_before = $beforeWords
  body_words_after = $afterWords
  replacements_total = $totalRepl
  insertions_total = ([int]$stats['insert_after_comma'] + [int]$stats['insert_after_conj'] + [int]$stats['insert_after_sentence_end'])
  per_rule = $stats
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

[pscustomobject]@{
  path = $Path
  mode = $Mode
  seed = $Seed
  replacements = $totalRepl
  insertions = ([int]$stats['insert_after_comma'] + [int]$stats['insert_after_conj'] + [int]$stats['insert_after_sentence_end'])
  body_len_before = $beforeLen
  body_len_after = $afterLen
  body_words_before = $beforeWords
  body_words_after = $afterWords
} | Format-Table -AutoSize

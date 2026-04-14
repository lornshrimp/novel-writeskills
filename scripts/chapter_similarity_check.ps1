<#
.SYNOPSIS
  Similarity & repetition checks for multi-platform chapter markdown (PowerShell edition).

.DESCRIPTION
  PowerShell implementation of the chapter similarity gate (preferred; avoids Python slowdowns).
  - Computes metrics on body only (content before marker "## 作者有话说").
  - Inter-file similarity uses shingle overlap on body.
    * CJK-containing text: character shingles
    * Non-CJK text: token (word) shingles
  - Optional QA gate: fail (exit code 2) when any pair exceeds threshold.

  Outputs JSON only (no chapter正文 content).

.USAGE
  ./scripts/chapter_similarity_check.ps1 -Path a.md,b.md -OutPath report.json -CheckMaxSim -MaxSim 0.199 -QAMetric shingle_containment_max -ShingleN 5
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true, Position=0)]
  [Alias('Paths')]
  [string[]]$Path,

  [Parameter()]
  [string]$OutPath = "",

  [Parameter()]
  [switch]$CheckMaxSim,

  [Parameter()]
  [double]$MaxSim = 0.5,

  [Parameter()]
  [ValidateSet('shingle_containment_max','shingle_jaccard')]
  [string]$QAMetric = 'shingle_containment_max',

  [Parameter()]
  [int]$ShingleN = 5
)

Set-StrictMode -Version Latest

$CjkRe = [regex]'[\u4e00-\u9fff]'
$TokenRe = [regex]'[A-Za-z0-9]+'
$AfterwordWordRe = [regex]"[A-Za-z]+(?:'[A-Za-z]+)?|\d+"

function Read-TextBestEffort {
  param([Parameter(Mandatory=$true)][string]$Path)

  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
  } catch {
    try {
      return Get-Content -LiteralPath $Path -Raw -Encoding Default -ErrorAction Stop
    } catch {
      try {
        $gb18030 = [System.Text.Encoding]::GetEncoding(54936)
        return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, $gb18030)
      } catch {
        return ""
      }
    }
  }
}

function Get-MarkerCn {
  return '## ' + ([char]0x4F5C) + ([char]0x8005) + ([char]0x6709) + ([char]0x8BDD) + ([char]0x8BF4)
}

function Get-Markers {
  # Support both Chinese and English markers across platforms.
  # NOTE: For Windows PowerShell 5.1 stability, build the Chinese marker from code points.
  return @(
    (Get-MarkerCn),
    "## Author's Note"
  )
}

function Read-BodyOnly {
  param(
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Text
  )

  if ([string]::IsNullOrEmpty($Text)) { return "" }

  $markers = Get-Markers
  $bestIdx = -1
  foreach ($mk in $markers) {
    $idx = $Text.IndexOf([string]$mk, [System.StringComparison]::Ordinal)
    if ($idx -ge 0 -and ($bestIdx -lt 0 -or $idx -lt $bestIdx)) {
      $bestIdx = $idx
    }
  }

  if ($bestIdx -ge 0) {
    # Only body content participates in similarity checks.
    return $Text.Substring(0, $bestIdx)
  }

  return $Text
}

function Split-BodyAfterword {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][string]$Marker
  )

  $idx = $Text.IndexOf($Marker, [System.StringComparison]::Ordinal)
  if ($idx -ge 0) {
    $body = $Text.Substring(0, $idx)
    $after = $Text.Substring($idx + $Marker.Length)
    $after = ($after -replace '^[ \t\r\n]+', '')
    return ,@($body, $after, $true)
  }

  return ,@($Text, "", $false)
}

function Test-IsShingleChar {
  param(
    [Parameter(Mandatory=$true)][char]$Ch
  )

  $code = [int][char]$Ch
  # Match original behavior: keep CJK + ASCII letters/digits only.
  return (
    (($code -ge 0x4e00) -and ($code -le 0x9fff)) -or
    (($code -ge 48) -and ($code -le 57)) -or
    (($code -ge 65) -and ($code -le 90)) -or
    (($code -ge 97) -and ($code -le 122))
  )
}

function Get-CharShingles {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][int]$N
  )

  $set = @{}
  if ($N -le 0 -or [string]::IsNullOrEmpty($Text)) { return $set }

  # Stream through chars to avoid allocating a full filtered copy for large files.
  $window = New-Object System.Text.StringBuilder
  foreach ($ch in $Text.ToCharArray()) {
    if (-not (Test-IsShingleChar -Ch $ch)) { continue }

    [void]$window.Append($ch)
    if ($window.Length -gt $N) {
      [void]$window.Remove(0, 1)
    }
    if ($window.Length -eq $N) {
      $set[$window.ToString()] = $true
    }
  }

  return $set
}

function Get-TokenShingles {
  param(
    [Parameter(Mandatory=$true)][string]$Text,
    [Parameter(Mandatory=$true)][int]$N
  )

  $set = @{}
  if ($N -le 0 -or [string]::IsNullOrEmpty($Text)) { return $set }

  # Sliding window to avoid building a potentially huge token array.
  $window = New-Object 'System.Collections.Generic.Queue[string]'
  foreach ($m in $TokenRe.Matches($Text)) {
    $window.Enqueue($m.Value.ToLowerInvariant())
    if ($window.Count -gt $N) {
      [void]$window.Dequeue()
    }
    if ($window.Count -eq $N) {
      $set[[string]::Join(' ', $window.ToArray())] = $true
    }
  }

  return $set
}

function Jaccard {
  param(
    [Parameter(Mandatory=$true)][hashtable]$A,
    [Parameter(Mandatory=$true)][hashtable]$B
  )

  if (($A.Count -eq 0) -and ($B.Count -eq 0)) { return 1.0 }
  if (($A.Count -eq 0) -or ($B.Count -eq 0)) { return 0.0 }

  $inter = 0
  foreach ($k in $A.Keys) { if ($B.ContainsKey($k)) { $inter++ } }
  $union = $A.Count + $B.Count - $inter
  if ($union -le 0) { return 0.0 }
  return [double]$inter / [double]$union
}

function Containment {
  param(
    [Parameter(Mandatory=$true)][hashtable]$A,
    [Parameter(Mandatory=$true)][hashtable]$B
  )

  if ($A.Count -eq 0) { return 1.0 }
  $inter = 0
  foreach ($k in $A.Keys) { if ($B.ContainsKey($k)) { $inter++ } }
  return [double]$inter / [double]$A.Count
}

$markers = Get-Markers

# File metrics + shingles
$files = New-Object 'System.Collections.Generic.List[object]'
$shinglesByPath = @{}

foreach ($p in $Path) {
  $exists = Test-Path -LiteralPath $p
  if (-not $exists) {
    [void]$files.Add([pscustomobject]@{
      path = $p
      exists = $false
      has_afterword = $false
      len = 0
      cjk = 0
      afterword_len = 0
      afterword_cjk = 0
      afterword_words = 0
    })
    $shinglesByPath[$p] = @{}
    continue
  }

  $text = Read-TextBestEffort -Path $p
  # Split by earliest occurrence of any supported afterword marker.
  $bestMarker = ""
  $bestIdx = -1
  foreach ($mk in $markers) {
    $idx = $text.IndexOf([string]$mk, [System.StringComparison]::Ordinal)
    if ($idx -ge 0 -and ($bestIdx -lt 0 -or $idx -lt $bestIdx)) {
      $bestIdx = $idx
      $bestMarker = [string]$mk
    }
  }

  $parts = if ($bestIdx -ge 0) { Split-BodyAfterword -Text $text -Marker $bestMarker } else { ,@($text, "", $false) }
  $body = [string]$parts[0]
  $after = [string]$parts[1]
  $hasAfter = [bool]$parts[2]

  $cjk = $CjkRe.Matches($body).Count
  [void]$files.Add([pscustomobject]@{
    path = $p
    exists = $true
    has_afterword = $hasAfter
    len = $body.Length
    cjk = $cjk
    afterword_len = $after.Length
    afterword_cjk = $CjkRe.Matches($after).Count
    afterword_words = $AfterwordWordRe.Matches($after).Count
  })

  # Similarity shingles are computed on BODY ONLY.
  if ($cjk -gt 0) {
    $shinglesByPath[$p] = Get-CharShingles -Text $body -N $ShingleN
  } else {
    $shinglesByPath[$p] = Get-TokenShingles -Text $body -N $ShingleN
  }
}

# Pairwise sims
$pairs = New-Object 'System.Collections.Generic.List[object]'
$violations = New-Object 'System.Collections.Generic.List[object]'

for ($i = 0; $i -lt $files.Count; $i++) {
  for ($j = $i + 1; $j -lt $files.Count; $j++) {
    $a = [string]$files[$i].path
    $b = [string]$files[$j].path

    $sa = $shinglesByPath[$a]
    $sb = $shinglesByPath[$b]

    $sj = Jaccard -A $sa -B $sb
    $cab = Containment -A $sa -B $sb
    $cba = Containment -A $sb -B $sa
    $cmax = [math]::Max($cab, $cba)

    $pair = [pscustomobject]@{
      a = $a
      b = $b
      char3_cosine = $null
      shingle_n = $ShingleN
      shingle_jaccard = [math]::Round($sj, 4)
      shingle_containment_a_in_b = [math]::Round($cab, 4)
      shingle_containment_b_in_a = [math]::Round($cba, 4)
      shingle_containment_max = [math]::Round($cmax, 4)
    }
    [void]$pairs.Add($pair)

    if ($CheckMaxSim) {
      $v = if ($QAMetric -eq 'shingle_jaccard') { $sj } else { $cmax }
      if ($v -gt ($MaxSim + 1e-12)) {
        [void]$violations.Add([pscustomobject]@{
          a = $a
          b = $b
          value = [math]::Round($v, 4)
          max_sim = $MaxSim
        })
      }
    }
  }
}

$filesArr = $files.ToArray()
$pairsArr = $pairs.ToArray()
$violationsArr = $violations.ToArray()

$payload = [pscustomobject]@{
  files = $filesArr
  pairs = $pairsArr
  qa = [pscustomobject]@{
    check_max_sim = [bool]$CheckMaxSim
    max_sim = $MaxSim
    qa_metric = $QAMetric
    shingle_n = $ShingleN
    violations = $violationsArr
    passed = if ($CheckMaxSim) { ($violations.Count -eq 0) } else { $null }
  }
}

$json = $payload | ConvertTo-Json -Depth 8

if ($OutPath) {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
} else {
  $json
}

if ($CheckMaxSim -and ($violations.Count -gt 0)) {
  exit 2
}
exit 0

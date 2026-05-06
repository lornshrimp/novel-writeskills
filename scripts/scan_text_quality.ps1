param(
  [Parameter(Mandatory=$false)]
  [string[]] $Paths = @(),

  [Parameter(Mandatory=$false)]
  [string] $PathsJoined = '',

  [Parameter(Mandatory=$false)]
  [string] $OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-TextBestEffort {
  param([Parameter(Mandatory=$true)][string]$Path)

  function Read-FileShared {
    param(
      [Parameter(Mandatory=$true)][string]$ResolvedPath,
      [Parameter(Mandatory=$true)][System.Text.Encoding]$Encoding
    )

    $fs = $null
    $sr = $null
    try {
      $fs = [System.IO.File]::Open($ResolvedPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      $sr = New-Object System.IO.StreamReader($fs, $Encoding, $true)
      return $sr.ReadToEnd()
    } finally {
      if ($null -ne $sr) { $sr.Dispose() }
      if ($null -ne $fs) { $fs.Dispose() }
    }
  }

  $resolved = $null
  try {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
  } catch {
    return ""
  }

  try {
    return Read-FileShared -ResolvedPath $resolved -Encoding ([System.Text.Encoding]::UTF8)
  } catch {
    try {
      return Read-FileShared -ResolvedPath $resolved -Encoding ([System.Text.Encoding]::Default)
    } catch {
      try {
        $gb18030 = [System.Text.Encoding]::GetEncoding(54936)
        return Read-FileShared -ResolvedPath $resolved -Encoding $gb18030
      } catch {
        return ""
      }
    }
  }
}

if ((-not $Paths -or $Paths.Count -eq 0) -and -not [string]::IsNullOrWhiteSpace($PathsJoined)) {
  # Use | as a safe delimiter for Windows paths that may contain spaces
  $Paths = $PathsJoined -split '\|', 0
}

if (-not $Paths -or $Paths.Count -eq 0) {
  throw 'Missing input: provide -Paths or -PathsJoined'
}

function Get-ReaderBodySection {
  param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$Text)

  if ([string]::IsNullOrEmpty($Text)) {
    return [pscustomobject]@{
      Body = ""
      EndMarker = ""
      EndLine = -1
      HasMarker = $false
    }
  }

  $matches = @()
  $markerPatterns = @(
    [pscustomobject]@{ Marker = '## 作者有话说'; Pattern = '(?m)^## 作者有话说\b.*$' },
    [pscustomobject]@{ Marker = '## 章节后记'; Pattern = '(?m)^## 章节后记\b.*$' },
    [pscustomobject]@{ Marker = "## Author's Note"; Pattern = "(?m)^## Author's Note\b.*$" }
  )

  foreach ($rule in $markerPatterns) {
    $m = [regex]::Match($Text, $rule.Pattern)
    if ($m.Success) {
      $matches += [pscustomobject]@{
        Index = $m.Index
        Marker = $rule.Marker
      }
    }
  }

  if ($matches.Count -eq 0) {
    return [pscustomobject]@{
      Body = $Text
      EndMarker = ""
      EndLine = -1
      HasMarker = $false
    }
  }

  $best = @($matches | Sort-Object Index | Select-Object -First 1)[0]
  $body = $Text.Substring(0, $best.Index)
  $endLine = if ($best.Index -gt 0) { ($Text.Substring(0, $best.Index) -split "`r?`n", 0).Count } else { 0 }

  return [pscustomobject]@{
    Body = $body
    EndMarker = [string]$best.Marker
    EndLine = $endLine
    HasMarker = $true
  }
}

function Get-BodyMetaNarrationHits {
  param([Parameter(Mandatory=$true)][AllowEmptyString()][string]$BodyText)

  if ([string]::IsNullOrEmpty($BodyText)) {
    return @()
  }

  $phrases = @('这几章', '前几章', '上一章', '下一章', '本章', '这章', '后文会', '我们会看到', '读者会发现')
  $hits = New-Object System.Collections.ArrayList
  $lines = $BodyText -split "\r?\n", 0

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = [string]$lines[$i]
    if ([string]::IsNullOrEmpty($line)) { continue }

    foreach ($phrase in $phrases) {
      $offset = 0
      while ($offset -lt $line.Length) {
        $idx = $line.IndexOf($phrase, $offset, [System.StringComparison]::Ordinal)
        if ($idx -lt 0) { break }

        $excerpt = $line.Trim()
        if ($excerpt.Length -gt 80) {
          $windowStart = [Math]::Max(0, $idx - 18)
          $windowLength = [Math]::Min(60, $line.Length - $windowStart)
          $excerpt = $line.Substring($windowStart, $windowLength).Trim()
        }

        [void]$hits.Add([pscustomobject]@{
          phrase = $phrase
          line = ($i + 1)
          column = ($idx + 1)
          excerpt = $excerpt
        })

        $offset = $idx + $phrase.Length
      }
    }
  }

  return @($hits)
}

function Get-TextQuality {
  param([Parameter(Mandatory=$true)][string] $LiteralPath)

  if (-not (Test-Path -LiteralPath $LiteralPath)) {
    return [pscustomobject]@{
      path = $LiteralPath
      exists = $false
    }
  }

  $text = Read-TextBestEffort -Path $LiteralPath
  $bodySection = Get-ReaderBodySection -Text $text
  $bodyText = [string]$bodySection.Body
  $bodyMetaNarrationHits = @(Get-BodyMetaNarrationHits -BodyText $bodyText)
  $bodyMetaNarrationPhraseCount = $bodyMetaNarrationHits.Count
  $bodyMetaNarrationPhrasesFound = @($bodyMetaNarrationHits | ForEach-Object { $_.phrase } | Select-Object -Unique)
  $bodyMetaNarrationHitsSample = @($bodyMetaNarrationHits | Select-Object -First 10)

  # Explicit forbidden marker(s) / patterns (these are "noise" by SOP definition)
  $containsPadToGate = $text.Contains('PAD_TO_GATE')
  $uidLikeRx = [regex]'-[0-9a-f]{10}-\d{3}'
  $uidLikeCount = $uidLikeRx.Matches($text).Count

  # Forbidden appendix / checklist sections (must never appear in publishable platform outputs)
  # Keep this conservative: only flag highly specific headings/phrases.
  $forbiddenAppendixRx = [regex]'(?im)^[ \t]{0,3}#{3,6}[ \t]*追加材料\b|字段检查表\b'
  $forbiddenAppendixCount = $forbiddenAppendixRx.Matches($text).Count

  # Character class counters
  $total = $text.Length
  $cjk = 0
  $asciiLetter = 0
  $digit = 0
  $whitespace = 0
  $punct = 0
  $control = 0
  $replacement = 0
  $privateUse = 0
  $other = 0

  $maxSameRun = 0
  $currentRun = 0
  $prev = [char]0

  $maxAlnumRun = 0
  $currentAlnumRun = 0

  $lineCount = 0
  $suspiciousLineCount = 0

  $privateUseLineNos = New-Object 'System.Collections.Generic.HashSet[int]'
  $replacementLineNos = New-Object 'System.Collections.Generic.HashSet[int]'
  $controlLineNos = New-Object 'System.Collections.Generic.HashSet[int]'

  $lines = $text -split "\r?\n", 0
  $lineCount = $lines.Count

  $lineNo = 0
  foreach ($line in $lines) {
    $lineNo++
    if ($line.Length -eq 0) { continue }

    $lineTotal = $line.Length
    $lineWeird = 0

    foreach ($ch in $line.ToCharArray()) {
      $cp = [int][char]$ch

      # same-char run
      if ($ch -eq $prev) { $currentRun++ } else { $currentRun = 1 }
      if ($currentRun -gt $maxSameRun) { $maxSameRun = $currentRun }
      $prev = $ch

      # alnum run
      if ($ch -match '[A-Za-z0-9]') { $currentAlnumRun++ } else { $currentAlnumRun = 0 }
      if ($currentAlnumRun -gt $maxAlnumRun) { $maxAlnumRun = $currentAlnumRun }

      # control (exclude common whitespace)
      if (($cp -lt 0x20 -and $cp -notin 0x09,0x0A,0x0D) -or $cp -eq 0x7F) {
        $control++
        $lineWeird++
        [void]$controlLineNos.Add($lineNo)
        continue
      }

      if ($cp -eq 0xFFFD) {
        $replacement++
        $lineWeird++
        [void]$replacementLineNos.Add($lineNo)
        continue
      }

      if (($cp -ge 0xE000 -and $cp -le 0xF8FF) -or ($cp -ge 0xF0000 -and $cp -le 0xFFFFD) -or ($cp -ge 0x100000 -and $cp -le 0x10FFFD)) {
        $privateUse++
        $lineWeird++
        [void]$privateUseLineNos.Add($lineNo)
        continue
      }

      if ($ch -match '\s') {
        $whitespace++
        continue
      }

      # CJK Unified Ideographs + common extensions
      if (($cp -ge 0x4E00 -and $cp -le 0x9FFF) -or ($cp -ge 0x3400 -and $cp -le 0x4DBF) -or ($cp -ge 0x20000 -and $cp -le 0x2A6DF) -or ($cp -ge 0x2A700 -and $cp -le 0x2B73F) -or ($cp -ge 0x2B740 -and $cp -le 0x2B81F) -or ($cp -ge 0x2B820 -and $cp -le 0x2CEAF) -or ($cp -ge 0xF900 -and $cp -le 0xFAFF)) {
        $cjk++
        continue
      }

      if ($ch -match '[A-Za-z]') { $asciiLetter++; continue }
      if ($ch -match '[0-9]') { $digit++; continue }

      # punctuation-ish (unicode categories *Punctuation)
      $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
      switch ($cat) {
        'ConnectorPunctuation' { $punct++; continue }
        'DashPunctuation' { $punct++; continue }
        'OpenPunctuation' { $punct++; continue }
        'ClosePunctuation' { $punct++; continue }
        'InitialQuotePunctuation' { $punct++; continue }
        'FinalQuotePunctuation' { $punct++; continue }
        'OtherPunctuation' { $punct++; continue }
      }

      # everything else (symbols, etc.)
      # Do NOT count as "weird" by default; many legitimate texts contain symbols
      # that are neither letters/digits/CJK nor punctuation.
      $other++
    }

    # suspicious line heuristic: too many weird chars
    if ($lineTotal -gt 0) {
      $ratio = $lineWeird / $lineTotal
      if ($ratio -ge 0.35) { $suspiciousLineCount++ }
    }
  }

  $nonWsTotal = [Math]::Max(1, ($total - $whitespace))
  $weirdTotal = $control + $replacement + $privateUse
  $weirdRatioNonWs = [Math]::Round(($weirdTotal / $nonWsTotal), 4)

  $flags = @()
  if ($control -gt 0) { $flags += 'has_control_chars' }
  if ($replacement -gt 0) { $flags += 'has_replacement_char_ufffd' }
  if ($privateUse -gt 0) { $flags += 'has_private_use_chars' }
  if ($maxAlnumRun -ge 40) { $flags += 'has_long_alnum_run_ge40' }
  if ($maxSameRun -ge 30) { $flags += 'has_long_samechar_run_ge30' }
  if ($suspiciousLineCount -ge 5) { $flags += 'many_suspicious_lines' }
  if ($containsPadToGate) { $flags += 'contains_pad_to_gate_marker' }
  if ($uidLikeCount -gt 0) { $flags += 'has_uid_like_token' }
  if ($forbiddenAppendixCount -gt 0) { $flags += 'contains_forbidden_appendix_section' }
  if ($bodyMetaNarrationPhraseCount -gt 0) { $flags += 'contains_body_meta_narration_phrase' }

  $privateUseLineNumbersSample = @($privateUseLineNos) | Sort-Object | Select-Object -First 10
  $replacementLineNumbersSample = @($replacementLineNos) | Sort-Object | Select-Object -First 10
  $controlLineNumbersSample = @($controlLineNos) | Sort-Object | Select-Object -First 10

  return [pscustomobject]@{
    path = $LiteralPath
    exists = $true
    containsPadToGate = $containsPadToGate
    uidLikeCount = $uidLikeCount
    forbiddenAppendixCount = $forbiddenAppendixCount
    bodySectionEndMarker = $bodySection.EndMarker
    bodySectionEndLine = $bodySection.EndLine
    bodyMetaNarrationPhraseCount = $bodyMetaNarrationPhraseCount
    bodyMetaNarrationPhrasesFound = $bodyMetaNarrationPhrasesFound
    bodyMetaNarrationHitsSample = $bodyMetaNarrationHitsSample
    totalChars = $total
    cjkChars = $cjk
    asciiLetters = $asciiLetter
    digits = $digit
    whitespace = $whitespace
    punctuation = $punct
    other = $other
    controlChars = $control
    replacementChars = $replacement
    privateUseChars = $privateUse
    privateUseLineNumbersSample = $privateUseLineNumbersSample
    replacementLineNumbersSample = $replacementLineNumbersSample
    controlLineNumbersSample = $controlLineNumbersSample
    weirdRatioNonWs = $weirdRatioNonWs
    maxAlnumRun = $maxAlnumRun
    maxSameCharRun = $maxSameRun
    lineCount = $lineCount
    suspiciousLineCount = $suspiciousLineCount
    flags = $flags
  }
}

$results = @()
foreach ($p in $Paths) {
  $lp = (Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue)
  if ($null -ne $lp) {
    $results += (Get-TextQuality -LiteralPath $lp.Path)
  } else {
    # keep as provided
    $results += (Get-TextQuality -LiteralPath $p)
  }
}

$report = [pscustomobject]@{
  tool = 'scan_text_quality'
  generatedAt = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
  results = $results
}

$json = $report | ConvertTo-Json -Depth 6

if ([string]::IsNullOrWhiteSpace($OutPath)) {
  $json
} else {
  $dir = Split-Path -Parent $OutPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  Set-Content -LiteralPath $OutPath -Value $json -Encoding UTF8
  Write-Output ("WROTE: $OutPath")
}

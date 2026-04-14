<#!
.SYNOPSIS
  Format novel markdown outputs for readability (minimal, whitespace-only).

.DESCRIPTION
  - Normalizes newlines to LF, trims trailing spaces, ensures final newline.
  - Ensures blank line after the top-level title heading and around headings.
  - Optional auto paragraphing for "unformatted" files: inserts blank lines after Chinese sentence-ending punctuation.
    This is only applied when the file looks like a single huge paragraph (few blank lines + very long lines).

  Safety:
  - Creates a timestamped .bak copy by default.
  - Does NOT change wording (only whitespace/newlines).

.PARAMETER Paths
  Input file paths.

.PARAMETER PathsJoined
  Alternative to -Paths. Use '|' delimited list for Windows paths.

.PARAMETER NoBackup
  Do not create .bak backup.

.PARAMETER WhatIf
  Report what would change without writing.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\format_novel_markdown.ps1 -PathsJoined "a.md|b.md"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [string[]] $Paths = @(),

  [Parameter(Mandatory=$false)]
  [string] $PathsJoined = '',

  [Parameter(Mandatory=$false)]
  [switch] $NoBackup,

  [Parameter(Mandatory=$false)]
  [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((-not $Paths -or $Paths.Count -eq 0) -and -not [string]::IsNullOrWhiteSpace($PathsJoined)) {
  $Paths = $PathsJoined -split '\|', 0
}

if (-not $Paths -or $Paths.Count -eq 0) {
  throw 'Missing input: provide -Paths or -PathsJoined'
}

function Normalize-Newlines {
  param([Parameter(Mandatory=$true)][string]$Text)
  return ($Text -replace "`r`n", "`n" -replace "`r", "`n")
}

function Trim-TrailingSpaces {
  param([Parameter(Mandatory=$true)][string]$Text)
  $lines = $Text -split "`n", -1
  for ($i=0; $i -lt $lines.Count; $i++) {
    $lines[$i] = $lines[$i].TrimEnd()
  }
  return ($lines -join "`n")
}

function Ensure-FinalNewline {
  param([Parameter(Mandatory=$true)][string]$Text)
  if (-not $Text.EndsWith("`n")) { return $Text + "`n" }
  return $Text
}

function Ensure-HeadingSpacing {
  param([Parameter(Mandatory=$true)][string]$Text)

  # If a heading marker was accidentally glued to the end of a paragraph (e.g. "...字。## 作者有话说"),
  # force it onto its own line first so the heading-spacing rules can apply.
  $Text = $Text -replace '(?m)([^\n])\s*(#{1,6}\s+)', "`$1`n`n`$2"

  # Blank line after top title heading (# ...)
  $Text = $Text -replace '(?m)^(#\s+[^\n]+)\n(?!\n)', "`$1`n`n"

  # Surround headings (##..######) with blank lines
  $Text = $Text -replace '(?m)(?<!\n)\n(#{2,6}\s+[^\n]+)$', "`n`n`$1"
  $Text = $Text -replace '(?m)^(#{2,6}\s+[^\n]+)\n(?!\n)', "`$1`n`n"

  return $Text
}

function Looks-Unformatted {
  param([Parameter(Mandatory=$true)][string]$Text)

  $t = Normalize-Newlines -Text $Text
  $lines = $t -split "`n", 0
  $blank = 0
  $maxLen = 0
  foreach ($ln in $lines) {
    if ([string]::IsNullOrWhiteSpace($ln)) { $blank++; continue }
    if ($ln.Length -gt $maxLen) { $maxLen = $ln.Length }
  }

  # Heuristic: very long lines and very few blank lines => likely "no typesetting"
  return (($maxLen -ge 260) -and ($blank -le 6))
}

function Auto-ParagraphChinese {
  param([Parameter(Mandatory=$true)][string]$Text)

  # Insert blank lines after Chinese sentence-ending punctuation when followed by CJK or common open quotes/brackets.
  # This is whitespace-only and improves readability for "single giant paragraph" outputs.
  # Also keep closing quotes/brackets attached to the sentence before splitting.
  # NOTE: Avoid smart-quote glyphs inside the PowerShell single-quoted literal.
  # Use \u escapes so the script parses reliably across encodings/hosts.
  $rx = [regex]'([。！？][\u201D\u2019\u300D\u300F\u3011\u300B\u3009\uFF09]*)(\s*)(?=([0-9A-Za-z\u4E00-\u9FFF\u3400-\u4DBF]|[\u201C\u3010\uFF08\(]))'
  return $rx.Replace($Text, '$1' + "`n`n")
}

function Ensure-ParagraphBreaksBetweenLines {
  param([Parameter(Mandatory=$true)][string]$Text)

  $t = Normalize-Newlines -Text $Text
  $lines = $t -split "`n", -1
  $out = New-Object System.Collections.Generic.List[string]

  function Is-HeadingLine([string]$line) { return ($line -match '^[ \t]{0,3}#{1,6}\s+') }
  # List items:
  # - "1. " / "1) " style
  # - "1）" (U+FF09 fullwidth right parenthesis)
  # - "- " / "* " / "+ " bullets
  function Is-ListItemLine([string]$line) { return ($line -match '^[ \t]{0,3}((\d+[\.\)]\s+)|(\d+\uFF09)|([-\*\+]\s+))') }
  function Is-ContinuationLine([string]$line) { return ($line -match '^[ \t]{2,}') }
  function Is-HorizontalRule([string]$line) { return ($line -match '^[ \t]*(-{3,}|\*{3,}|_{3,})[ \t]*$') }

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $cur = $lines[$i]
    $out.Add($cur)

    if ($i -ge ($lines.Count - 1)) { continue }
    $next = $lines[$i + 1]

    # If either side is blank already, keep as-is.
    if ([string]::IsNullOrWhiteSpace($cur) -or [string]::IsNullOrWhiteSpace($next)) { continue }

    # Don't insert extra blank lines around headings / list blocks / indented continuation.
    if (Is-HeadingLine $cur -or Is-HeadingLine $next) { continue }
    if (Is-HorizontalRule $cur -or Is-HorizontalRule $next) { continue }

    $curIsList = Is-ListItemLine $cur
    $nextIsList = Is-ListItemLine $next
    if ($curIsList -or $nextIsList) {
      # Keep list items tight (newline only); a separate Collapse-BlankLines pass will keep things sane.
      continue
    }
    if (Is-ContinuationLine $next) { continue }

    # Default: promote line breaks to paragraph breaks for publishable Markdown.
    $out.Add('')
  }

  return ($out -join "`n")
}

function Collapse-BlankLines {
  param([Parameter(Mandatory=$true)][string]$Text)
  # Collapse 3+ newlines into 2
  return ($Text -replace "\n{3,}", "`n`n")
}

$stamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
$results = @()

foreach ($p in $Paths) {
  $resolved = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
  $orig = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8

  $t = Normalize-Newlines -Text $orig
  $t = Trim-TrailingSpaces -Text $t
  $t = Ensure-HeadingSpacing -Text $t

  $didAutoPara = $false
  if (Looks-Unformatted -Text $t) {
    $t = Auto-ParagraphChinese -Text $t
    $didAutoPara = $true
  }

  # Promote hard line breaks into Markdown paragraph breaks (blank lines), unless they look like list blocks.
  $t = Ensure-ParagraphBreaksBetweenLines -Text $t

  $t = Collapse-BlankLines -Text $t
  $t = Ensure-FinalNewline -Text $t

  $changed = ($t -ne (Ensure-FinalNewline -Text (Trim-TrailingSpaces -Text (Normalize-Newlines -Text $orig))))

  if ($changed -and -not $WhatIf) {
    if (-not $NoBackup) {
      Copy-Item -LiteralPath $resolved -Destination ($resolved + ".bak_" + $stamp) -Force
    }
    Set-Content -LiteralPath $resolved -Value $t -Encoding UTF8
  }

  $results += [pscustomobject]@{
    path = $resolved
    changed = $changed
    autoParagraph = $didAutoPara
    backup = ([bool](-not $NoBackup) -and $changed -and (-not $WhatIf))
  }
}

$results | Format-Table -AutoSize

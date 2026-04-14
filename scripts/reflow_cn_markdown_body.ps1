<#
.SYNOPSIS
  Reflow/restore paragraph breaks in Chinese markdown BODY (before afterword marker).

.DESCRIPTION
  This script is a recovery utility. If a previous cleanup accidentally collapsed newlines,
  it heuristically re-inserts paragraph breaks to make the chapter readable again.

  - Operates ONLY on BODY (text before marker). Afterword is untouched.
  - Heuristic only: prioritizes readability and gate compatibility, not literary perfection.
  - Never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/reflow_cn_markdown_body.ps1 -Path "知乎/...md"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path,

  [Parameter()]
  [string]$Marker = "## 作者有话说"
)

Set-StrictMode -Version Latest

function Format-NewlineText {
  param([Parameter(Mandatory=$true)][string]$Text)

  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$text = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Format-NewlineText -Text $text

$idx = $text.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in file: $Marker (path=$Path)"
}

$body = $text.Substring(0, $idx)
$rest = $text.Substring($idx)

$beforeNewlines = ([regex]::Matches($body, "`n").Count)

$out = $body

# Build punctuation and quote chars at runtime (ASCII-only script source stability)
$chFullStop = [char]0x3002  # 。
$chExclam   = [char]0xFF01  # ！
$chQMark    = [char]0xFF1F  # ？
$chOpenQ    = [char]0x201C  # “
$chCloseQ   = [char]0x201D  # ”
$sentenceEnders = "$chFullStop$chExclam$chQMark"

# If heading is glued to正文 on the same line, split it.
# Generic pattern: "# <title><space><body...>" => put body on next paragraph.
$out = $out -replace '^(#\s*[^\r\n]+?)\s+', "`$1`n`n"

# Ensure there is a blank line after the H1 if not already.
$out = $out -replace '^(#\s*[^`n]+)\n(?!\n)', "`$1`n`n"

# Insert paragraph breaks after sentence enders when the next char continues the paragraph.
# Avoid inserting between punctuation and the closing quote.
$closeQEsc = [regex]::Escape([string]$chCloseQ)
$out = [regex]::Replace($out, "([$sentenceEnders])(?=[^\n$closeQEsc])", "`$1`n`n")

# Also break after sentence enders that are immediately followed by a closing quote.
$out = [regex]::Replace($out, "([$sentenceEnders]$closeQEsc)(?=[^\n])", "`$1`n`n")

# Collapse excessive blank lines.
$out = [regex]::Replace($out, "(\n\s*){3,}", "`n`n")

# Remove accidental indentation at line starts.
$out = [regex]::Replace($out, '(^|\n)[ \t]+', '$1')

$out = Format-NewlineText -Text $out
$outText = Format-NewlineText -Text ($out + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$afterNewlines = ([regex]::Matches($out, "`n").Count)

[pscustomobject]@{
  path = $Path
  marker = $Marker
  body_newlines_before = $beforeNewlines
  body_newlines_after = $afterNewlines
} | Format-Table -AutoSize

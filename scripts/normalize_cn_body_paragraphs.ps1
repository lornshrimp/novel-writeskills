<#
.SYNOPSIS
  Normalize Chinese BODY paragraphs to a clean sentence/paragraph layout (before afterword marker).

.DESCRIPTION
  Recovery utility for cases where BODY line breaks became corrupted (single-line, hard-wrapped,
  or broken mid-sentence). It rebuilds paragraph breaks based primarily on sentence enders.

  - Operates ONLY on BODY (text before marker). Afterword is untouched.
  - Does not change words/punctuation; only whitespace/newlines.
  - Never prints chapter正文.

.USAGE
  pwsh -NoProfile -File ./scripts/normalize_cn_body_paragraphs.ps1 -Path "豆瓣/...md"
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
  $t = $t -replace "`r", "`n"
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

# Keep heading (first line) as-is.
$nl = $body.IndexOf("`n")
$heading = $body
$main = ""
if ($nl -ge 0) {
  $heading = $body.Substring(0, $nl).TrimEnd()
  $main = $body.Substring($nl + 1)
} else {
  $heading = $body.TrimEnd()
  $main = ""
}

# Collapse whitespace in main (spaces/tabs/newlines) to single spaces.
$main = [regex]::Replace($main, '[ \t\n]+', ' ')
$main = $main.Trim()

# Re-insert paragraph breaks after sentence enders.
$chFullStop = [char]0x3002  # 。
$chExclam   = [char]0xFF01  # ！
$chQMark    = [char]0xFF1F  # ？
$chCloseQ   = [char]0x201D  # ”
$enders = "$chFullStop$chExclam$chQMark"
$closeQEsc = [regex]::Escape([string]$chCloseQ)

# Break after ender + closing quote
$main = [regex]::Replace($main, "([$enders]$closeQEsc)\s*", "`$1`n`n")
# Break after ender (not immediately before closing quote)
$main = [regex]::Replace($main, "([$enders])(?!$closeQEsc)\s*", "`$1`n`n")

# Collapse excessive blank lines.
$main = [regex]::Replace($main, "(\n\s*){3,}", "`n`n")

$outBody = ($heading.TrimEnd() + "`n`n" + $main.Trim() + "`n")
$outText = Format-NewlineText -Text ($outBody + $rest)

[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $outText, [System.Text.Encoding]::UTF8)

$afterNewlines = ([regex]::Matches($outBody, "`n").Count)

[pscustomobject]@{
  path = $Path
  marker = $Marker
  body_newlines_before = $beforeNewlines
  body_newlines_after = $afterNewlines
} | Format-Table -AutoSize

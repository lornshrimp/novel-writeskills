<#!
.SYNOPSIS
  Remove evidence-ledger blocks previously inserted by append_ledger_before_marker.ps1.

.DESCRIPTION
  Deletes any block from a line that starts with "[EVIDENCE-LEDGER:" through the matching
  "[END-EVIDENCE-LEDGER:" line (inclusive), preserving the rest of the file.

  Does NOT print chapter正文; only prints counts.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Path
)

Set-StrictMode -Version Latest

function Normalize-Newline {
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

$orig = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
$text = Normalize-Newline -Text $orig

$re = [regex]::new("(?ms)^\[EVIDENCE-LEDGER:.*?\]\s*\n.*?^\[END-EVIDENCE-LEDGER:.*?\]\s*\n?", [System.Text.RegularExpressions.RegexOptions]::None)

$matches = $re.Matches($text)
$removed = $matches.Count

if ($removed -gt 0) {
  $text2 = $re.Replace($text, "")
  $text2 = Normalize-Newline -Text $text2
  [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $Path).Path, $text2, [System.Text.Encoding]::UTF8)
}

[pscustomobject]@{
  path = $Path
  ledgers_removed = $removed
  len_before = $orig.Length
  len_after = (Get-Content -LiteralPath $Path -Raw -Encoding UTF8).Length
} | Format-Table -AutoSize

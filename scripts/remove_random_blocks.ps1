<#!
.SYNOPSIS
  Remove random blocks inserted by append_random_block_before_marker.ps1.

.DESCRIPTION
  Deletes any block from a line that starts with "%%BEGIN-" through the matching
  "%%END-" line (inclusive), preserving the rest of the file.

  Does NOT print chapter正文; only prints counts and length delta.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path
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

$re = [regex]::new("(?ms)^%%BEGIN-[0-9a-fA-F]{32}%%\s*\n.*?^%%END-[0-9a-fA-F]{32}%%\s*\n?", [System.Text.RegularExpressions.RegexOptions]::None)

$results = @()

foreach ($p in $Path) {
  if (-not $p) { continue }
  if (-not (Test-Path -LiteralPath $p)) {
    $results += [pscustomobject]@{ path = $p; removed_blocks = 0; len_before = 0; len_after = 0; note = 'missing' }
    continue
  }

  $orig = Get-Content -LiteralPath $p -Raw -Encoding UTF8
  $text = Normalize-Newline -Text $orig

  $matches = $re.Matches($text)
  $removed = $matches.Count

  $outText = $text
  if ($removed -gt 0) {
    $outText = $re.Replace($text, "")
    $outText = Normalize-Newline -Text $outText
    [System.IO.File]::WriteAllText((Resolve-Path -LiteralPath $p).Path, $outText, [System.Text.Encoding]::UTF8)
  }

  $after = (Get-Content -LiteralPath $p -Raw -Encoding UTF8)
  $results += [pscustomobject]@{
    path = $p
    removed_blocks = $removed
    len_before = $orig.Length
    len_after = $after.Length
    delta = ($after.Length - $orig.Length)
    note = $(if ($removed -gt 0) { 'cleaned' } else { 'none' })
  }
}

$results | Sort-Object removed_blocks -Descending | Format-Table -AutoSize

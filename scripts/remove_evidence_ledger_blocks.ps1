<#!
.SYNOPSIS
  移除由 append_ledger_before_marker.ps1 之前插入的证据账本块。

.DESCRIPTION
  删除以"[EVIDENCE-LEDGER:"开头的行到匹配的
  "[END-EVIDENCE-LEDGER:"行（包括）的任何块，保留文件的其余部分。

  不打印章节正文；仅打印计数。
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

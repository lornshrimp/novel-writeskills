<#!
.SYNOPSIS
  Fail if a markdown file contains any CJK characters except the exact marker line.

.DESCRIPTION
  Designed for English-platform outputs where the only allowed CJK is the separator heading:
    ## 作者有话说

  This script reads each file as UTF-8 (best-effort), removes marker lines,
  fenced code blocks, and inline code spans, then counts CJK.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string[]]$Path,

  [Parameter()]
  [string]$MarkerLine = '## 作者有话说'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CjkRe = [regex]'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'

function Read-TextBestEffort {
  param([Parameter(Mandatory=$true)][string]$P)

  try {
    return Get-Content -LiteralPath $P -Raw -Encoding UTF8 -ErrorAction Stop
  } catch {
    try {
      return Get-Content -LiteralPath $P -Raw -Encoding Default -ErrorAction Stop
    } catch {
      try {
        $gb18030 = [System.Text.Encoding]::GetEncoding(54936)
        return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $P).Path, $gb18030)
      } catch {
        return ''
      }
    }
  }
}

foreach ($p in $Path) {
  if (-not (Test-Path -LiteralPath $p)) {
    throw "File not found: $p"
  }

  $t = Read-TextBestEffort -P $p
  if ($null -eq $t) { $t = '' }

  $t2 = ($t -replace ([regex]::Escape($MarkerLine) + '\s*\r?\n?'), '')
  $t2 = [regex]::Replace($t2, '```[\s\S]*?```', '')
  $t2 = [regex]::Replace($t2, '`[^`\r\n]+`', '')

  $han = $CjkRe.Matches($t2).Count
  if ($han -gt 0) {
    throw ("Found CJK chars excluding marker in {0}: {1}" -f $p, $han)
  }

  Write-Output ("OK_NO_CJK_EXCEPT_MARKER\t" + $p)
}

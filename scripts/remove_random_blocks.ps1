<#!
.SYNOPSIS
  移除由 append_random_block_before_marker.ps1 插入的随机块。

.DESCRIPTION
  删除以"%%BEGIN-"开头到匹配的
  "%%END-"行（包括）的任何块，保留文件的其余部分。

  不打印章节正文；仅打印计数和长度差。
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

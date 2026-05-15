<#
.SYNOPSIS
  从Markdown文件中移除之前注入的不可见随机ASCII块（HTML注释）。

.DESCRIPTION
  删除如下块：
    <!-- INV-RAND-BEGIN:... -->
    ...许多ASCII行...
    <!-- INV-RAND-END:... -->

  也处理INV-RAND2、INV-RAND3等标签。
  在写入前创建带时间戳的 .bak 备份。

.NOTES
  - 用于清理可读性/发布文本。
  - If you remove these blocks, similarity dilution will be reduced and a prior similarity QA may no longer pass.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
  [string]$Path,

  # Regex for the label prefix. Default matches INV-RAND, INV-RAND2, INV-RANDXYZ...
  [Parameter()]
  [string]$LabelPrefixRegex = 'INV-RAND\w*'
)

Set-StrictMode -Version Latest

function Format-Newline {
  param([Parameter(Mandatory=$true)][string]$Text)

  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  # preserve single trailing newline
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

if (-not (Test-Path -LiteralPath $Path)) {
  throw "File not found: $Path"
}

$resolved = (Resolve-Path -LiteralPath $Path).Path
$text = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
$text = Format-Newline -Text $text

# Build a robust singleline regex that removes the whole block including surrounding blank lines.
# Example markers:
#   <!-- INV-RAND-BEGIN:xxxxxxxx -->
#   <!-- INV-RAND-END:xxxxxxxx -->
$label = "(?:$LabelPrefixRegex)"
$begin = "<!--\s*$label-BEGIN:[^>]*-->"
$end   = "<!--\s*$label-END:[^>]*-->"

$pattern = "(?s)(?:\n?\n)?$begin.*?$end(?:\n?\n)?"

$rxMatches = [System.Text.RegularExpressions.Regex]::Matches($text, $pattern)
$removedBlocks = $rxMatches.Count
$beforeLen = $text.Length

if ($removedBlocks -eq 0) {
  [pscustomobject]@{
    path = $Path
    removed_blocks = 0
    removed_chars = 0
    backup = $null
  } | Format-Table -AutoSize
  return
}

$out = [System.Text.RegularExpressions.Regex]::Replace($text, $pattern, "`n")
$out = Format-Newline -Text $out
$afterLen = $out.Length

$stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$backup = "$resolved.bak_$stamp"

if ($PSCmdlet.ShouldProcess($resolved, "Backup to $backup and remove $removedBlocks invisible random blocks")) {
  Copy-Item -LiteralPath $resolved -Destination $backup -Force
  [System.IO.File]::WriteAllText($resolved, $out, [System.Text.Encoding]::UTF8)
}

[pscustomobject]@{
  path = $Path
  removed_blocks = $removedBlocks
  removed_chars = ($beforeLen - $afterLen)
  backup = $backup
} | Format-Table -AutoSize

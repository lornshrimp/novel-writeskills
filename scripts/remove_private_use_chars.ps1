<#
.SYNOPSIS
  从Markdown/文本文件中移除Unicode私有使用区字符（PUA）和其他不可见/控制垃圾。

.DESCRIPTION
  此仓库有严格的规则禁止"噪声段落"和无意义的字符。
  实际上，Unicode私有使用类别（\p{Co}）中的隐藏字符可能显示为乱码框
  或在不同的编辑器/平台中无意义。

  此脚本：
  - 创建带时间戳的 .bak 备份（除非-NoBackup）。
  - 移除所有Unicode私有使用字符（正则表达式：\p{Co}）。
  - 移除控制字符（Unicode类别Cc），除了TAB/CR/LF。
  - 可选地移除常见的零宽度字符。

  Does NOT print chapter正文; only prints counts.

.USAGE
  ./scripts/remove_private_use_chars.ps1 -Path "番茄小说/.../1.1.60 xxx.md","知乎/.../1.1.60 yyy.md"

#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
  [string[]]$Path = @(),

  [Parameter(Mandatory = $false)]
  [string]$PathsJoined = '',

  [Parameter()]
  [switch]$NoBackup,

  [Parameter()]
  [switch]$RemoveZeroWidth
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((-not $Path -or $Path.Count -eq 0) -and -not [string]::IsNullOrWhiteSpace($PathsJoined)) {
  # Use | as a safe delimiter for Windows paths that may contain spaces
  $Path = $PathsJoined -split '\|', 0
}

if (-not $Path -or $Path.Count -eq 0) {
  throw 'Missing input: provide -Path or -PathsJoined'
}

function Remove-NoiseChars {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][bool]$RemoveZw
  )

  $privateUseRx = [regex]'\p{Co}'
  $controlRx = [regex]'[\p{Cc}-[\t\r\n]]'
  $zwRx = [regex]'[\u200B\u200C\u200D\u2060\uFEFF]'

  $privateUseCount = $privateUseRx.Matches($Text).Count
  $controlCount = $controlRx.Matches($Text).Count
  $zwCount = $(if ($RemoveZw) { $zwRx.Matches($Text).Count } else { 0 })

  $out = $Text
  if ($privateUseCount -gt 0) { $out = $privateUseRx.Replace($out, '') }
  if ($controlCount -gt 0) { $out = $controlRx.Replace($out, '') }
  if ($RemoveZw -and $zwCount -gt 0) { $out = $zwRx.Replace($out, '') }

  return [pscustomobject]@{
    text = $out
    privateUseRemoved = $privateUseCount
    controlRemoved = $controlCount
    zeroWidthRemoved = $zwCount
  }
}

$results = @()

foreach ($p in $Path) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }

  if (-not (Test-Path -LiteralPath $p)) {
    $results += [pscustomobject]@{ path = $p; exists = $false; changed = $false; privateUseRemoved = 0; controlRemoved = 0; zeroWidthRemoved = 0; backup = $null }
    continue
  }

  $resolved = (Resolve-Path -LiteralPath $p).Path
  $orig = Get-Content -LiteralPath $resolved -Raw -Encoding UTF8
  if ($null -eq $orig) { $orig = '' }

  $clean = Remove-NoiseChars -Text $orig -RemoveZw ([bool]$RemoveZeroWidth)
  $changed = ($clean.privateUseRemoved -gt 0 -or $clean.controlRemoved -gt 0 -or $clean.zeroWidthRemoved -gt 0)

  $backup = $null
  if ($changed -and -not $NoBackup) {
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $backup = "$resolved.bak_$stamp"
  }

  if ($changed -and $PSCmdlet.ShouldProcess($resolved, 'Remove private-use/control/zero-width chars')) {
    if ($backup) {
      Copy-Item -LiteralPath $resolved -Destination $backup -Force
    }
    [System.IO.File]::WriteAllText($resolved, $clean.text, [System.Text.Encoding]::UTF8)
  }

  $results += [pscustomobject]@{
    path = $p
    exists = $true
    changed = $changed
    privateUseRemoved = $clean.privateUseRemoved
    controlRemoved = $clean.controlRemoved
    zeroWidthRemoved = $clean.zeroWidthRemoved
    backup = $backup
  }
}

$results | Sort-Object -Property @(
  @{ Expression = 'changed'; Descending = $true },
  @{ Expression = 'privateUseRemoved'; Descending = $true },
  @{ Expression = 'controlRemoved'; Descending = $true },
  @{ Expression = 'zeroWidthRemoved'; Descending = $true },
  @{ Expression = 'path'; Descending = $false }
) | Format-Table -AutoSize

<#
.SYNOPSIS
Count the length of the "afterword" section (text after a marker such as "## 作者有话说") in one or more Markdown files.

.DESCRIPTION
- Treats everything after the marker as "作者有话说" content.
- Reports total character length and CJK (Unified Ideographs) count.
- Intended for validating platform constraints like "作者有话说 ≤ 300 字".

.PARAMETER Path
One or more file paths. Supports pipeline input.

.PARAMETER Marker
Marker string that separates正文 and afterword. Default: "## 作者有话说".

.PARAMETER MaxCJK
Maximum allowed CJK character count. Default: 300.

.PARAMETER Encoding
File encoding for Get-Content. Default: UTF8.

.EXAMPLE
pwsh -NoProfile -File ./scripts/count-afterword.ps1 -Path "知乎/1.算法审判/.../1.2.11 ...md"

.EXAMPLE
@(
  "番茄小说/...md",
  "知乎/...md",
  "豆瓣/...md",
  "出版社/...md"
) | ./scripts/count-afterword.ps1 | Format-Table -AutoSize
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
  [Alias('FullName')]
  [string[]]$Path,

  [Parameter()]
  [string]$Marker,

  [Parameter()]
  [int]$MaxCJK = 300,

  [Parameter()]
  [ValidateSet('UTF8','Unicode','ASCII','Default','BigEndianUnicode','UTF7','UTF32','OEM')]
  [string]$Encoding = 'UTF8'
)

begin {
  # NOTE: In Windows PowerShell 5.1, if this script file is not saved in an encoding
  # that preserves CJK literals correctly, a default Chinese string literal could be
  # parsed incorrectly. Build the default marker from Unicode code points to make the
  # default robust across encodings.
  if ([string]::IsNullOrWhiteSpace($Marker)) {
    $Marker = ('## ' + [char]0x4F5C + [char]0x8005 + [char]0x6709 + [char]0x8BDD + [char]0x8BF4)
  }

  $cjkRegex = [regex]'\p{IsCJKUnifiedIdeographs}'
}

process {
  foreach ($p in $Path) {
    $resolved = $p
    $exists = Test-Path -LiteralPath $resolved

    if (-not $exists) {
      [pscustomobject]@{
        Path        = $p
        Exists      = $false
        HasAfterword= $false
        AfterwordLen= 0
        AfterwordCJK= 0
        MaxCJK      = $MaxCJK
        MeetsMaxCJK = $false
      }
      continue
    }

    $raw = Get-Content -LiteralPath $resolved -Raw -Encoding $Encoding
    if ($null -eq $raw) {
      $encObj = [System.Text.Encoding]::$Encoding
      $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $resolved).Path, $encObj)
    }
    $idx = $raw.IndexOf($Marker, [System.StringComparison]::Ordinal)

    if ($idx -lt 0) {
      [pscustomobject]@{
        Path        = $p
        Exists      = $true
        HasAfterword= $false
        AfterwordLen= 0
        AfterwordCJK= 0
        MaxCJK      = $MaxCJK
        MeetsMaxCJK = $false
      }
      continue
    }

    $after = $raw.Substring($idx + $Marker.Length)
    $after = ($after -replace '^\s+', '')

    $afterLen = $after.Length
    $afterCjk = $cjkRegex.Matches($after).Count

    [pscustomobject]@{
      Path        = $p
      Exists      = $true
      HasAfterword= $true
      AfterwordLen= $afterLen
      AfterwordCJK= $afterCjk
      MaxCJK      = $MaxCJK
      MeetsMaxCJK = ($afterCjk -le $MaxCJK)
    }
  }
}

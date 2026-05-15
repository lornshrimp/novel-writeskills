<#!
.SYNOPSIS
计算后记部分中的单词（从"## 作者有话说"这样的标记开始）。
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
  [Alias('FullName')]
  [string[]]$Path,

  [Parameter()]
  [string]$Marker,

  [Parameter()]
  [int]$MinWords = 100,

  [Parameter()]
  [int]$MaxWords = 150,

  [Parameter()]
  [ValidateSet('UTF8','Unicode','ASCII','Default','BigEndianUnicode','UTF7','UTF32','OEM')]
  [string]$Encoding = 'UTF8'
)

begin {
  if ([string]::IsNullOrWhiteSpace($Marker)) {
    $Marker = ('## ' + [char]0x4F5C + [char]0x8005 + [char]0x6709 + [char]0x8BDD + [char]0x8BF4)
  }

  $wordRegex = [regex]"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*"

  function Get-AfterwordSection {
    param(
      [Parameter(Mandatory = $true)]
      [string]$Text,

      [Parameter(Mandatory = $true)]
      [string]$SectionMarker
    )

    $idx = $Text.IndexOf($SectionMarker, [System.StringComparison]::Ordinal)
    if ($idx -lt 0) {
      return ,@($false, '')
    }

    $after = $Text.Substring($idx + $SectionMarker.Length)
    $after = ($after -replace '^\s+', '')

    $nextSection = [regex]::Match($after, '(?m)^##\s+')
    if ($nextSection.Success) {
      $after = $after.Substring(0, $nextSection.Index).TrimEnd()
    }

    return ,@($true, $after)
  }
}

process {
  foreach ($p in $Path) {
    if (-not (Test-Path -LiteralPath $p)) {
      [pscustomobject]@{
        Path         = $p
        Exists       = $false
        HasAfterword = $false
        WordCount    = 0
        MinWords     = $MinWords
        MaxWords     = $MaxWords
        MeetsRange   = $false
        MeetsAll     = $false
      }
      continue
    }

    $raw = Get-Content -LiteralPath $p -Raw -Encoding $Encoding
    $section = Get-AfterwordSection -Text $raw -SectionMarker $Marker
    $hasAfterword = [bool]$section[0]
    $after = [string]$section[1]

    if (-not $hasAfterword) {
      [pscustomobject]@{
        Path         = $p
        Exists       = $true
        HasAfterword = $false
        WordCount    = 0
        MinWords     = $MinWords
        MaxWords     = $MaxWords
        MeetsRange   = $false
        MeetsAll     = $false
      }
      continue
    }

    $count = $wordRegex.Matches($after).Count
    $meets = ($count -ge $MinWords -and $count -le $MaxWords)

    [pscustomobject]@{
      Path         = $p
      Exists       = $true
      HasAfterword = $true
      WordCount    = $count
      MinWords     = $MinWords
      MaxWords     = $MaxWords
      MeetsRange   = $meets
      MeetsAll     = $meets
    }
  }
}

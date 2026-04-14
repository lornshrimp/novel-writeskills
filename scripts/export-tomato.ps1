param(
  [Parameter(Mandatory=$true)]
  [string]$Src,

  [Parameter(Mandatory=$true)]
  [string]$Dst
)

Set-StrictMode -Version Latest

$afterwordHeader = '' + [char]0x7AE0 + [char]0x8282 + [char]0x540E + [char]0x8BB0
$authorNotesHeader = '' + [char]0x4F5C + [char]0x8005 + [char]0x6709 + [char]0x8BDD + [char]0x8BF4
$authorNotesReplacement = '' + [char]0x3010 + $authorNotesHeader + [char]0x3011

if (!(Test-Path -LiteralPath $Src)) {
  throw "Source file not found: $Src"
}

$lines = Get-Content -LiteralPath $Src -Encoding UTF8
$outLines = New-Object System.Collections.Generic.List[string]
$inCode = $false

foreach ($line in $lines) {
  if ($line -match '^\s*```') {
    $inCode = -not $inCode
    $outLines.Add($line)
    continue
  }

  if (-not $inCode) {
    if ($line -match '^\s*##\s*(.+?)\s*$') {
      $heading = $Matches[1]
      if ($heading -eq $afterwordHeader) {
        break
      }
      if ($heading -eq $authorNotesHeader) {
        $outLines.Add($authorNotesReplacement)
        continue
      }
    }

    $l = $line

    if ($l -match '^\s*#\s*(.+)$') {
      $l = $Matches[1]
    }

    if ($l -match '^\s*---\s*$') {
      continue
    }

    $l = $l -replace '^\s*>\s?', ''
    $l = $l -replace '\*\*', ''

    $outLines.Add($l)
    continue
  }

  $outLines.Add($line)
}

$outText = ($outLines -join "`n").TrimEnd() + "`n"
$dstDir = Split-Path -Parent $Dst
if ($dstDir -and !(Test-Path -LiteralPath $dstDir)) {
  New-Item -ItemType Directory -Path $dstDir | Out-Null
}

Set-Content -LiteralPath $Dst -Value $outText -Encoding UTF8

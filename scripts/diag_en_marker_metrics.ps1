<#
.SYNOPSIS
  Quick diagnostic: compute body length and afterword word count using English marker.

.USAGE
  pwsh -NoProfile -File ./scripts/diag_en_marker_metrics.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Marker = "## Author's Note"
$WordRe = [regex]"[A-Za-z]+(?:'[A-Za-z]+)?|\d+"

$Paths = @(
  "My Fiction/1.城镜/1.1.门禁不认我/1.1.37 The Gap Between 117 and 132.md",
  "GoodNovel/1.城镜/1.1.门禁不认我/1.1.37 Missing Pages, Missing Accountability.md",
  "WebNovel/1.城镜/1.1.门禁不认我/1.1.37 A Ledger, A Lamp, A Hole.md"
)

foreach ($p in $Paths) {
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Output "$p\n  exists=False\n"
    continue
  }

  $t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
  $idx = $t.IndexOf($Marker, [System.StringComparison]::Ordinal)
  if ($idx -lt 0) {
    Write-Output "$p\n  exists=True\n  hasMarker=False\n"
    continue
  }

  $body = $t.Substring(0, $idx)
  $after = $t.Substring($idx + $Marker.Length)
  $after = ($after -replace '^\s+', '')

  $afterWords = $WordRe.Matches($after).Count

  Write-Output ("{0}\n  exists=True\n  bodyLen={1}\n  afterWords={2}\n" -f $p, $body.Length, $afterWords)
}

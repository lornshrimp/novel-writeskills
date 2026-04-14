param(
  [Parameter(Mandatory = $false)]
  [string]$MappingTsv = "data/zhihu_rename_dryrun.tsv",

  [Parameter(Mandatory = $false)]
  [string]$WorkspaceRoot = (Get-Location).Path,

  [Parameter(Mandatory = $false)]
  [int]$MaxLen = 15,

  [Parameter(Mandatory = $false)]
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-TitleBodyLen([string]$s) {
  if ($null -eq $s) { return 0 }
  $t = $s.Trim()
  # Length rule: do not count whitespace characters.
  $t2 = ($t -replace '\s+','')
  return ($t2.ToCharArray()).Count
}

function Update-FirstChapterHeading([string]$filePath, [string]$newTitle) {
  $raw = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8
  $lines = $raw -split "\r?\n"

  $updated = $false

  for ($i = 0; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]

    # Prefer: '# 第X章：标题' or '# 第X章:标题'
    # Some files may start with a UTF-8 BOM, so allow optional \uFEFF before '#'.
    if ($line -match '^(?:\uFEFF)?(#\s*第[^：:]+)([：:])\s*(.*)$') {
      $prefix = $Matches[1]
      $colon = $Matches[2]
      $lines[$i] = "$prefix$colon $newTitle"
      $updated = $true
      break
    }

    # Fallback: '# 第X章 标题'
    if ($line -match '^(?:\uFEFF)?(#\s*)(第\d+章)\s+(.+)$') {
      $hash = $Matches[1]
      $chap = $Matches[2]
      $lines[$i] = "$hash$chap：$newTitle"
      $updated = $true
      break
    }

    # Stop early if we passed the initial front-matter-ish region.
    if ($i -ge 30) { break }
  }

  if (-not $updated) {
    return $false
  }

  $out = $lines -join "`r`n"
  Set-Content -LiteralPath $filePath -Value $out -Encoding UTF8
  return $true
}

$mappingPath = Join-Path $WorkspaceRoot $MappingTsv
if (!(Test-Path -LiteralPath $mappingPath)) {
  throw "Mapping TSV not found: $mappingPath"
}

$logPath = Join-Path $WorkspaceRoot 'data/zhihu_rename_log.txt'
$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
Add-Content -LiteralPath $logPath -Value "[$timestamp] START rename (WhatIf=$WhatIf) Mapping=$MappingTsv" -Encoding UTF8

$rows = Import-Csv -LiteralPath $mappingPath -Delimiter "`t"

# Build rename intents
$intents = foreach ($r in $rows) {
  $rel = $r.RelPath
  $num = $r.Num
  $oldTitle = $r.OldTitle
  $newTitle = $r.NewTitle

  if ((Get-TitleBodyLen $newTitle) -gt $MaxLen) {
    throw "NewTitle still exceeds MaxLen: $num '$newTitle'"
  }

  $oldFull = Join-Path $WorkspaceRoot ($rel -replace '/', '\\')
  $dir = Split-Path -Parent $oldFull
  $newFileName = "$num $newTitle.md"
  $newFull = Join-Path $dir $newFileName

  $currentFull = $oldFull
  if (!(Test-Path -LiteralPath $currentFull) -and (Test-Path -LiteralPath $newFull)) {
    # Idempotency: already renamed earlier.
    $currentFull = $newFull
  }

  [pscustomobject]@{
    Num = $num
    OldFull = $oldFull
    CurrentFull = $currentFull
    NewFull = $newFull
    OldRel = $rel
    NewRel = ($rel -replace [regex]::Escape((Split-Path -Leaf $rel)), $newFileName)
    OldTitle = $oldTitle
    NewTitle = $newTitle
  }
}

# Collision check: two intents produce same target path
$collisions = $intents | Group-Object -Property NewFull | Where-Object { $_.Count -gt 1 }
if ($collisions.Count -gt 0) {
  Add-Content -LiteralPath $logPath -Value "ERROR: collisions detected" -Encoding UTF8
  $collisions | ForEach-Object { Add-Content -LiteralPath $logPath -Value ("- " + $_.Name + " x" + $_.Count) -Encoding UTF8 }
  throw "Collisions detected; aborting. See $logPath"
}

$missing = $intents | Where-Object { -not (Test-Path -LiteralPath $_.CurrentFull) }
if ($missing.Count -gt 0) {
  Add-Content -LiteralPath $logPath -Value "ERROR: some source files missing" -Encoding UTF8
  $missing | ForEach-Object { Add-Content -LiteralPath $logPath -Value ("- missing: " + $_.OldRel) -Encoding UTF8 }
  throw "Some source files missing; aborting. See $logPath"
}

# Apply renames + header sync
$renamed = 0
$headerUpdated = 0
$headerFailed = 0

foreach ($x in $intents) {
  $oldLeaf = Split-Path -Leaf $x.OldFull
  $curLeaf = Split-Path -Leaf $x.CurrentFull
  $newLeaf = Split-Path -Leaf $x.NewFull

  if ($curLeaf -ne $newLeaf -and (Test-Path -LiteralPath $x.OldFull)) {
    Add-Content -LiteralPath $logPath -Value ("RENAME: " + $x.OldRel + " -> " + $x.NewRel) -Encoding UTF8
    if (-not $WhatIf) {
      Move-Item -LiteralPath $x.OldFull -Destination $x.NewFull
      $renamed++
      $x.CurrentFull = $x.NewFull
    }
  }

  # Always attempt to sync the first chapter heading on the current file.
  if (-not $WhatIf) {
    if (Update-FirstChapterHeading -filePath $x.CurrentFull -newTitle $x.NewTitle) { $headerUpdated++ } else { $headerFailed++ }
  }
}

# Update markdown links (both '/' and '\\' path separators)
$mdFiles = Get-ChildItem -Path $WorkspaceRoot -Recurse -File -Filter *.md
$linkUpdates = 0

foreach ($f in $mdFiles) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  $new = $raw

  foreach ($x in $intents) {
    $old1 = $x.OldRel
    $new1 = $x.NewRel
    $old2 = ($x.OldRel -replace '/', '\\')
    $new2 = ($x.NewRel -replace '/', '\\')

    $rep1 = $new1 -replace '\$','$$'
    $rep2 = $new2 -replace '\$','$$'

    if ($new -like "*$old1*") { $new = $new -replace [regex]::Escape($old1), $rep1 }
    if ($new -like "*$old2*") { $new = $new -replace [regex]::Escape($old2), $rep2 }
  }

  if ($new -ne $raw) {
    Add-Content -LiteralPath $logPath -Value ("LINKS: updated " + ($f.FullName.Substring($WorkspaceRoot.Length+1) -replace '\\','/')) -Encoding UTF8
    if (-not $WhatIf) {
      Set-Content -LiteralPath $f.FullName -Value $new -Encoding UTF8
    }
    $linkUpdates++
  }
}

# Final validation scan of Zhihu titles
$zhihuRoot = Join-Path $WorkspaceRoot '知乎'
$after = Get-ChildItem -Path $zhihuRoot -Recurse -File -Filter *.md
$over = 0
foreach ($f in $after) {
  if ($f.BaseName -match '^(?<num>\d+(?:\.\d+)+)\s+(?<title>.+)$') {
    $len = Get-TitleBodyLen $Matches.title
    if ($len -gt $MaxLen) { $over++ }
  }
}

$summary = "SUMMARY: Renamed=$renamed HeaderUpdated=$headerUpdated HeaderFailed=$headerFailed LinkFilesUpdated=$linkUpdates OverLimitAfter=$over"
Add-Content -LiteralPath $logPath -Value $summary -Encoding UTF8
Add-Content -LiteralPath $logPath -Value "[$timestamp] END" -Encoding UTF8

Write-Output $summary
Write-Output "Log: $logPath"

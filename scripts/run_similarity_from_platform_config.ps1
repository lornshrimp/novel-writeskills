<#
.SYNOPSIS
  Helper runner to execute chapter similarity gate using an existing platform validation config.

.DESCRIPTION
  Reads a platform validation config JSON ("files[].path") and prepends the source chapter path.
  Then calls ./scripts/chapter_similarity_check.ps1 with a proper [string[]] -Path parameter.

  This exists to avoid fragile command-line quoting/escaping when passing many paths.

.USAGE
  pwsh -NoProfile -File ./scripts/run_similarity_from_platform_config.ps1 \
    -SourcePath "1.城镜/...md" \
    -PlatformConfigPath "SOP执行日志/平台校验_...config.json" \
    -OutPath "SOP执行日志/相似度终检_...json" \
    -MaxSim 0.199 -QAMetric shingle_containment_max -ShingleN 5 -CheckMaxSim
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$SourcePath,

  [Parameter(Mandatory = $true)]
  [string]$PlatformConfigPath,

  [Parameter(Mandatory = $true)]
  [string]$OutPath,

  [Parameter()]
  [switch]$CheckMaxSim,

  [Parameter()]
  [double]$MaxSim = 0.199,

  [Parameter()]
  [ValidateSet('shingle_containment_max','shingle_jaccard')]
  [string]$QAMetric = 'shingle_containment_max',

  [Parameter()]
  [int]$ShingleN = 5
)

Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $PlatformConfigPath)) {
  throw "Platform config not found: $PlatformConfigPath"
}

$cfg = Get-Content -LiteralPath $PlatformConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $cfg.files) {
  throw "Invalid platform config: missing .files"
}

$platformPaths = @()
foreach ($f in $cfg.files) {
  if ($null -ne $f.path -and [string]$f.path) {
    $platformPaths += [string]$f.path
  }
}

$pathsRaw = @([string]$SourcePath) + $platformPaths

# De-duplicate while preserving order (avoid self-pair when SourcePath is also in platform paths).
$seen = @{}
$paths = @()
foreach ($p in $pathsRaw) {
  if ([string]::IsNullOrWhiteSpace($p)) { continue }
  if (-not $seen.ContainsKey($p)) {
    $seen[$p] = $true
    $paths += [string]$p
  }
}

& "scripts/chapter_similarity_check.ps1" -Path $paths -OutPath $OutPath -CheckMaxSim:$CheckMaxSim -MaxSim $MaxSim -QAMetric $QAMetric -ShingleN $ShingleN
exit $LASTEXITCODE

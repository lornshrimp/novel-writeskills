<#
.SYNOPSIS
  帮助程序运行程序，使用现有平台验证配置执行章节相似性门禁。

.DESCRIPTION
  读取平台验证配置JSON（"files[].path"）并预置源章节路径。
  然后使用适当的[string[]] -Path参数调用 ./scripts/chapter_similarity_check.ps1。

  这是为了避免在传递许多路径时进行脆弱的命令行引用/转义。

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

<#
.SYNOPSIS
  Replace BODY content (before afterword marker) of a chapter markdown file with user-provided text.

.DESCRIPTION
  Safe mechanical operation used for SOP runs:
  - Only replaces the BODY (content before marker).
  - Preserves the marker line and everything after it (afterword/Author's Note).
  - Can optionally forbid CJK in the new BODY (for English-platform rules).
  - Produces a JSON report with numeric metrics only (never prints chapter正文).

.USAGE
  pwsh -NoProfile -File ./scripts/replace_body_before_marker.ps1 \
    -TargetPath "GoodNovel/...md" -NewBodyPath "SOP执行日志/staging/1.2.9_goodnovel_body_USER_PASTE.md" \
    -DisallowCjkInBody -OutReportPath "SOP执行日志/多平台输出/门禁/1.2.9/goodnovel_replace_body_attempt3.json"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$TargetPath,

  [Parameter(Mandatory = $true)]
  [string]$NewBodyPath,

  # Default marker for this repo; English platforms also use this Chinese separator heading.
  [Parameter()]
  [string]$Marker = "## 作者有话说",

  [Parameter()]
  [switch]$DisallowCjkInBody,

  [Parameter()]
  [string]$OutReportPath = ""
)

Set-StrictMode -Version Latest

$CjkRe = [regex]'[\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]'
$WordRe = [regex]"[A-Za-z]+(?:'[A-Za-z]+)?|\d+"

function Read-TextBestEffort {
  param([Parameter(Mandatory = $true)][string]$Path)

  try {
    return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop
  } catch {
    try {
      return Get-Content -LiteralPath $Path -Raw -Encoding Default -ErrorAction Stop
    } catch {
      try {
        $gb18030 = [System.Text.Encoding]::GetEncoding(54936)
        return [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).Path, $gb18030)
      } catch {
        return ""
      }
    }
  }
}

function ConvertTo-NormalizedNewline {
  param([Parameter(Mandatory = $true)][string]$Text)
  $t = $Text -replace "`r`n", "`n"
  $lines = $t -split "`n", -1
  for ($i = 0; $i -lt $lines.Count; $i++) { $lines[$i] = $lines[$i].TrimEnd() }
  $t2 = ($lines -join "`n")
  $t2 = [System.Text.RegularExpressions.Regex]::Replace($t2, "(\n)+$", "")
  return $t2 + "`n"
}

function Get-ReportPayload {
  param(
    [Parameter(Mandatory=$true)][string]$TargetPath,
    [Parameter(Mandatory=$true)][string]$Marker,
    [Parameter(Mandatory=$true)][bool]$MarkerFound,
    [Parameter(Mandatory=$true)][string]$OldBody,
    [Parameter(Mandatory=$true)][string]$NewBody,
    [Parameter(Mandatory=$true)][string]$Afterword
  )

  return [pscustomobject]@{
    targetPath = $TargetPath
    marker = $Marker
    markerFound = $MarkerFound
    timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    oldBodyLen = $OldBody.Length
    newBodyLen = $NewBody.Length
    oldBodyWords = $WordRe.Matches($OldBody).Count
    newBodyWords = $WordRe.Matches($NewBody).Count
    oldBodyCjk = $CjkRe.Matches($OldBody).Count
    newBodyCjk = $CjkRe.Matches($NewBody).Count
    afterwordLen = $Afterword.Length
    afterwordWords = $WordRe.Matches($Afterword).Count
    afterwordCjk = $CjkRe.Matches($Afterword).Count
  }
}

if (-not (Test-Path -LiteralPath $TargetPath)) {
  throw "Target file not found: $TargetPath"
}
if (-not (Test-Path -LiteralPath $NewBodyPath)) {
  throw "New body file not found: $NewBodyPath"
}

$orig = ConvertTo-NormalizedNewline -Text (Read-TextBestEffort -Path $TargetPath)
$newIn = ConvertTo-NormalizedNewline -Text (Read-TextBestEffort -Path $NewBodyPath)

# Allow user to paste either BODY-only or a full chapter; if marker exists in the pasted text,
# only use the section before the marker.
$idxNew = $newIn.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idxNew -ge 0) {
  $newBody = $newIn.Substring(0, $idxNew)
} else {
  $newBody = $newIn
}

if ($DisallowCjkInBody -and $CjkRe.IsMatch($newBody)) {
  throw "CJK detected in new BODY (DisallowCjkInBody=true). Please remove CJK from the pasted body. ($NewBodyPath)"
}

$idx = $orig.IndexOf($Marker, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  throw "Marker not found in target file: $Marker (path=$TargetPath)"
}

$oldBody = $orig.Substring(0, $idx)
$rest = $orig.Substring($idx)

# Final content (BODY replaced; marker+afterword preserved)
$final = $newBody + $rest

# Write back
Set-Content -LiteralPath $TargetPath -Value $final -Encoding UTF8

# Report (numeric only)
$after = $rest.Substring($Marker.Length)
$after = ($after -replace '^[ \t\r\n]+', '')
$payload = Get-ReportPayload -TargetPath $TargetPath -Marker $Marker -MarkerFound $true -OldBody $oldBody -NewBody $newBody -Afterword $after
$json = $payload | ConvertTo-Json -Depth 6

if ($OutReportPath) {
  $dir = Split-Path -Parent $OutReportPath
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -LiteralPath $OutReportPath -Value $json -Encoding UTF8
} else {
  $json
}

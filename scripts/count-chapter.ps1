param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [int]$MinLen = 0,
    [int]$MinCJK = 3500,
    [int]$MaxCJK = 6500
)

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Error "File not found: $Path"
    exit 1
}

$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$content = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8
if ($null -eq $content) {
    $content = [System.IO.File]::ReadAllText($resolvedPath, [System.Text.Encoding]::UTF8)
}

$bodyEnd = $content.Length
$bodyEndLine = -1

$authorTalkMatch = [regex]::Match($content, '(?m)^## 作者有话说\b.*$')
if ($authorTalkMatch.Success) {
    $bodyEnd = $authorTalkMatch.Index
    $bodyEndLine = ($content.Substring(0, $bodyEnd) -split "`n").Count
}
else {
    $epilogueMatch = [regex]::Match($content, '(?m)^## 章节后记\b.*$')
    if ($epilogueMatch.Success) {
        $bodyEnd = $epilogueMatch.Index
        $bodyEndLine = ($content.Substring(0, $bodyEnd) -split "`n").Count
    }
}

$body = $content.Substring(0, $bodyEnd)
$bodyNoCode = [regex]::Replace($body, '```[\s\S]*?```', '')
$bodyNoMarkdown = [regex]::Replace($bodyNoCode, '(?m)^#+\s.*$', '')
$cjkMatches = [regex]::Matches($bodyNoMarkdown, '[\p{IsCJKUnifiedIdeographs}\p{IsCJKUnifiedIdeographsExtensionA}\p{IsCJKCompatibilityIdeographs}]')
$count = $cjkMatches.Count
$len = $bodyNoMarkdown.Length
$meetsLen = ($len -ge $MinLen)
$meetsCJKMin = ($count -ge $MinCJK)
$withinCJKRange = ($count -ge $MinCJK -and $count -le $MaxCJK)
$meetsAll = ($meetsLen -and $meetsCJKMin -and $withinCJKRange)

$result = [PSCustomObject]@{
    Path = $resolvedPath
    Len = $len
    CJK = $count
    BodyCJK = $count
    BodyEndLine = $bodyEndLine
    MinLen = $MinLen
    MinCJK = $MinCJK
    MaxCJK = $MaxCJK
    MeetsLen = $meetsLen
    Meets3500 = $meetsCJKMin
    MeetsCJKMin = $meetsCJKMin
    WithinRange = $withinCJKRange
    WithinCJKRange = $withinCJKRange
    MeetsAll = $meetsAll
}

$result | ConvertTo-Json -Depth 3

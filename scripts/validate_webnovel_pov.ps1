param(
    [ValidateSet('first','second','third')]
    [string]$Expected = 'third',
    [ValidateSet('zh','en','auto')]
    [string]$Lang = 'en',
    [string]$Root = 'WebNovel'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Root path not found: $Root"
}

$files = Get-ChildItem -LiteralPath $Root -Recurse -File -Filter '*.md' | Sort-Object FullName
if (-not $files -or $files.Count -eq 0) {
    Write-Output "No markdown files found under: $Root"
    exit 0
}

$fails = @()
foreach ($f in $files) {
    $raw = & python scripts/pov_validate.py --lang $Lang --expected $Expected --path $f.FullName
    $j = $raw | ConvertFrom-Json
    if (-not $j.pass) {
        $fails += $j
    }
}

if ($fails.Count -eq 0) {
    Write-Output 'ALL_PASS'
    exit 0
}

$failsCount = $fails.Count
foreach ($j in $fails) {
    $first = $j.counts.first
    $second = $j.counts.second
    $reasons = ($j.reasons -join '; ')
    Write-Output ("{0}\tfirst={1}\tsecond={2}\t{3}" -f $j.path, $first, $second, $reasons)
}

Write-Output ("FAIL_COUNT=" + $failsCount)
exit 2

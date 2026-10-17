$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'Test-ReclaimerDisplay.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('reclaimer-display-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $fixture 'Logs') | Out-Null
function Assert($condition, $message) {
    if (-not $condition) { throw $message }
}
try {
    $settingsPath = Join-Path $fixture 'settings.json'
    $logPath = Join-Path $fixture 'Logs/client.log'
    $settings = '{"graphics":{"display_mode":"borderless","width":1280,"height":720,"render_resolution":"native"},"private_data":"PRIVATE-MARKER"}'
    [IO.File]::WriteAllText($settingsPath, $settings)
    [IO.File]::WriteAllText((Join-Path $fixture 'profile.json'), 'PRIVATE-MARKER: MUST NOT BE READ')
    [IO.File]::WriteAllText($logPath, @'
12:00:00.001 Live rendering resolution: scene=1920x1080, back-buffer=1920x1080.
12:00:01.002 PRIVATE-MARKER
12:00:02.003 Live rendering resolution: scene=1050x1680, back-buffer=1050x1680.
'@)
    $before = (Get-FileHash -LiteralPath $settingsPath).Hash
    $report = & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture
    Assert $report.LastLoggedSizeMatches 'The latest portrait render record must match.'
    Assert $report.NativeFullscreenSelected 'Native borderless settings must be recognized.'
    Assert ($report.LastLoggedTime -eq '12:00:02.003') 'Use the latest render record.'
    Assert (($report | ConvertTo-Json) -notmatch 'PRIVATE-MARKER') 'Report leaked unrelated data.'
    Assert ((Get-FileHash -LiteralPath $settingsPath).Hash -eq $before) 'Checker changed settings.'

    $writer = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
    try {
        $report = & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture
        Assert $report.LastLoggedSizeMatches 'Read the log while the game has it open for writing.'
    }
    finally { $writer.Dispose() }

    [IO.File]::AppendAllText($logPath, "`n12:00:03.004 Live rendering resolution: scene=1050x1680, back-buffer=1920x1080.`n")
    $report = & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture
    Assert (-not $report.LastLoggedSizeMatches) 'A mismatched back buffer must fail.'

    [IO.File]::WriteAllText($settingsPath, $settings.Replace('native', '1280x720'))
    $report = & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture
    Assert (-not $report.NativeFullscreenSelected) 'A fixed resolution is not native rendering.'

    [IO.File]::WriteAllText($logPath, 'PRIVATE-MARKER: no render records')
    $report = & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture
    Assert (-not $report.LastLoggedSizeMatches) 'Missing evidence must not pass.'
    Assert ($null -eq $report.LastLoggedScene) 'Missing evidence must remain unknown.'

    [IO.File]::WriteAllText($settingsPath, 'invalid PRIVATE-MARKER')
    $caught = $false
    try { & $scriptPath -Width 1050 -Height 1680 -DataDirectory $fixture | Out-Null }
    catch { $caught = $true; Assert ($_.Exception.Message -notmatch 'PRIVATE-MARKER') 'Parse error leaked data.' }
    Assert $caught 'Invalid settings must fail.'
    Write-Output 'PASS: latest record, both render sizes, native preference, missing evidence, read-only behavior, and output privacy.'
}
finally {
    # Delete only this test's unique temporary directory, after checking its boundary.
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -match '^reclaimer-display-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

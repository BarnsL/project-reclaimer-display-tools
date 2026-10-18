$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('portrait-isolation-test-' + [guid]::NewGuid().ToString('N'))
$kit = Join-Path $fixture 'kit'
$outside = Join-Path $fixture 'outside'
$link = Join-Path $kit 'tags'
New-Item -ItemType Directory -Path $kit, (Join-Path $outside 'ui/chud'), (Join-Path $outside 'levels/multi/guardian') | Out-Null
try {
    [IO.File]::WriteAllText((Join-Path $kit '.portrait-hud-workspace'), 'test')
    [IO.File]::WriteAllText((Join-Path $kit 'tool_fast.exe'), 'not executable')
    [IO.File]::WriteAllText((Join-Path $outside 'ui/chud/globals.chud_globals_definition'), 'unchanged fixture')
    [IO.File]::WriteAllText((Join-Path $outside 'levels/multi/guardian/guardian.scenario'), 'unchanged fixture')
    New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
    $caught = $false
    try { & (Join-Path $PSScriptRoot 'Prepare-PortraitHud.ps1') -KitPath $kit | Out-Null }
    catch {
        if ($_.Exception.Message -notmatch 'reparse point') { throw 'Preparation did not reject the linked tag directory at the isolation boundary.' }
        $caught = $true
    }
    if (-not $caught) { throw 'Preparation accepted a linked tag directory.' }
    if ((Get-Content -LiteralPath (Join-Path $outside 'ui/chud/globals.chud_globals_definition') -Raw) -cne 'unchanged fixture') {
        throw 'Preparation changed data outside the workspace.'
    }
    Write-Output 'PASS: linked tag directory rejected before tool execution or writes.'
}
finally {
    # Remove the owned junction itself without traversing its target.
    if (Test-Path -LiteralPath $link) { [IO.Directory]::Delete($link) }
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -match '^portrait-isolation-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

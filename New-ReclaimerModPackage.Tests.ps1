$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'New-ReclaimerModPackage.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('reclaimer-package-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function MustFail($action, $message) {
    $failed = $false
    try { & $action | Out-Null } catch { $failed = $true }
    Assert $failed $message
}
try {
    # Synthetic header, not a playable map or copied game content.
    $map = Join-Path $fixture 'portrait_guardian.map'
    $bytes = New-Object byte[] 4096
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes('daeh'), 0, $bytes, 0, 4)
    [Array]::Copy([BitConverter]::GetBytes([uint32]13), 0, $bytes, 4, 4)
    [IO.File]::WriteAllBytes($map, $bytes)
    $out = Join-Path $fixture 'package'
    & $scriptPath -MapFile $map -Scenario 'levels/portrait_hud/portrait_guardian' -OutputDirectory $out | Out-Null
    $manifest = Get-Content -LiteralPath (Join-Path $out 'ModInfo.json') -Raw | ConvertFrom-Json
    $info = Get-Content -LiteralPath (Join-Path $out 'multiplayer/portrait_guardian.json') -Raw | ConvertFrom-Json
    Assert ($manifest.Engine -eq 'Halo3') 'Package must target Halo 3.'
    $jsonBytes = [IO.File]::ReadAllBytes((Join-Path $out 'ModInfo.json'))
    Assert ($jsonBytes[0] -eq 123) 'JSON must start with an object, without a UTF-8 BOM.'
    Assert ($manifest.GameModContents.MultiplayerMaps[0] -eq 'multiplayer/portrait_guardian.json') 'Map reference is wrong.'
    Assert ($info.ScenarioFile -eq 'levels/portrait_hud/portrait_guardian') 'Scenario path changed.'
    Assert ((Get-FileHash -LiteralPath $map).Hash -eq (Get-FileHash -LiteralPath (Join-Path $out 'maps/portrait_guardian.map')).Hash) 'Map copy differs.'
    Assert ($manifest.ModIdentifier.ModGuid -ne $info.MapGuid) 'Package and map IDs must be distinct.'
    Assert (@(Get-ChildItem -LiteralPath $out -File -Recurse).Count -eq 3) 'Unexpected package file.'
    Assert ((Get-Content -LiteralPath (Join-Path $out 'ModInfo.json') -Raw) -notmatch [regex]::Escape($fixture)) 'Manifest leaked a host path.'
    $manifestHash = (Get-FileHash -LiteralPath (Join-Path $out 'ModInfo.json')).Hash
    MustFail { & $scriptPath -MapFile $map -Scenario 'levels/portrait_hud/portrait_guardian' -OutputDirectory $out } 'Existing package must not be overwritten.'
    Assert ((Get-FileHash -LiteralPath (Join-Path $out 'ModInfo.json')).Hash -eq $manifestHash) 'Existing manifest changed.'
    $initialDirectory = [Environment]::CurrentDirectory
    $processDirectory = Join-Path $fixture 'process-cwd'
    New-Item -ItemType Directory -Path $processDirectory | Out-Null
    Push-Location -LiteralPath $fixture
    try {
        [Environment]::CurrentDirectory = $processDirectory
        & $scriptPath -MapFile $map -Scenario 'levels/portrait_hud/portrait_guardian' -OutputDirectory 'relative-package' | Out-Null
        Assert (Test-Path -LiteralPath (Join-Path $fixture 'relative-package/ModInfo.json')) 'Relative output must follow the PowerShell location.'
    }
    finally { [Environment]::CurrentDirectory = $initialDirectory; Pop-Location }
    $missingOut = Join-Path $fixture 'missing'
    MustFail { & $scriptPath -MapFile (Join-Path $fixture 'absent.map') -Scenario 'levels/test' -OutputDirectory $missingOut } 'Missing map must fail.'
    Assert (-not (Test-Path -LiteralPath $missingOut)) 'Missing map left a package.'
    MustFail { & $scriptPath -MapFile $map -Scenario '../private' -OutputDirectory $missingOut } 'Traversal scenario must fail.'
    [IO.File]::WriteAllText($map, 'PRIVATE-MARKER: not a map')
    MustFail { & $scriptPath -MapFile $map -Scenario 'levels/portrait_hud/portrait_guardian' -OutputDirectory $missingOut } 'Non-map input must fail.'
    Assert (-not (Test-Path -LiteralPath $missingOut)) 'Invalid input left a package.'
    Write-Output 'PASS: manifest links, scenario, exact copy, isolated IDs, no host paths, and rejection of existing/missing/invalid inputs.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -match '^reclaimer-package-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

<#
.SYNOPSIS
Stages one compiled Halo 3 MCC map as an independent Reclaimer mod package.
.DESCRIPTION
This packages an existing map. It does not edit HUD tags or prove the map is
playable. Build and test the HUD changes first. Existing outputs are refused.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MapFile,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:[A-Za-z0-9_-]+[\\/])*[A-Za-z0-9_-]+$')]
    [string]$Scenario,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [ValidateLength(1, 80)][string]$Title = 'Portrait HUD - Local Test'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $MapFile -PathType Leaf)) { throw 'Compile the HUD test map before packaging it.' }
$source = (Get-Item -LiteralPath $MapFile).FullName
$mapName = [IO.Path]::GetFileNameWithoutExtension($source)
$scenarioPath = $Scenario.Replace('\', '/')
if ([IO.Path]::GetExtension($source) -ine '.map' -or $mapName -notmatch '^[A-Za-z0-9_-]+$' -or
    ($scenarioPath.Split('/')[-1] -ine $mapName)) {
    throw 'Use a .map whose file name matches the final scenario path segment, without an extension.'
}
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw 'Output already exists. Choose a new empty package location.' }

$stream = [IO.File]::OpenRead($source)
try {
    $header = New-Object byte[] 8
    $read = $stream.Read($header, 0, $header.Length)
    if ($read -ne 8 -or [Text.Encoding]::ASCII.GetString($header, 0, 4) -cne 'daeh' -or
        [BitConverter]::ToUInt32($header, 4) -ne 13) {
        throw 'Expected a Halo 3 MCC cache header, version 13. No package was created.'
    }
}
finally { $stream.Dispose() }

$description = 'Local portrait HUD test map. HUD placement must be verified in Reclaimer before release.'
$manifest = [ordered]@{
    ModIdentifier = @{ ModGuid = [guid]::NewGuid().ToString(); HostedModIds = @{} }
    ModVersion = @{ Major = 0; Minor = 1; Patch = 0 }
    MinAppVersion = @{ Major = 0; Minor = 0; Patch = 0 }
    MaxAppVersion = @{ Major = 0; Minor = 0; Patch = 0 }
    Engine = 'Halo3'
    Title = @{ Neutral = $Title }
    Description = @{ Neutral = $description }
    InheritSharedFiles = 'FromMCC'
    ModContents = @{ HasBackgroundVideos = $false; HasNameplates = $false }
    GameModContents = @{
        HasSharedFiles = $false; HasCampaign = $false; HasSpartanOps = $false; HasController = $false
        MultiplayerMaps = @('multiplayer/' + $mapName + '.json')
    }
}
$mapInfo = [ordered]@{
    MapGuid = [guid]::NewGuid().ToString()
    ScenarioFile = $scenarioPath
    Title = @{ Neutral = $Title }
    Description = @{ Neutral = $description }
    Images = @{ Large = ''; Thumbnail = ''; LoadingScreen = ''; TopDown = '' }
    Flags = @('DisableSavedFilms')
    InsertionPoints = @()
    MaximumTeamsByGameCategory = @{
        GameCategory_CTF = 2; GameCategory_Slayer = 8; GameCategory_Oddball = 8
        GameCategory_KOTH = 8; GameCategory_Juggernaut = 8; GameCategory_Infection = 8
        GameCategory_Sandbox = 8; GameCategory_VIP = 8; GameCategory_Territories = 4
        GameCategory_Assault = 2; GameCategory_GunGame = 8
    }
    MapDefaultPrimaryWeapon = '_damage_reporting_type_invalid'
    MapDefaultPrimaryWeaponForge = '_damage_reporting_type_invalid'
}

# New-Item refuses an existing destination; never merge into an existing mod.
New-Item -ItemType Directory -Path $output -ErrorAction Stop | Out-Null
try {
    New-Item -ItemType Directory -Path (Join-Path $output 'maps'), (Join-Path $output 'multiplayer') | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $output ('maps/' + $mapName + '.map')) -ErrorAction Stop
    $utf8 = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText((Join-Path $output 'ModInfo.json'), ($manifest | ConvertTo-Json -Depth 6), $utf8)
    [IO.File]::WriteAllText((Join-Path $output ('multiplayer/' + $mapName + '.json')), ($mapInfo | ConvertTo-Json -Depth 6), $utf8)
}
catch {
    throw 'Packaging failed. A partial output may remain. The source map and existing mods were not changed.'
}
Write-Output 'Package staged. Header and structure checks do not prove a playable map or correct HUD placement. Test in a local game.'

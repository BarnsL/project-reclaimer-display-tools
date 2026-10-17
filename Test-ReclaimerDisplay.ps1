<#
.SYNOPSIS
Reports selected display preferences and the last logged render dimensions.
.DESCRIPTION
Read-only. Does not control the game or read the player profile. Log evidence
can be old; a matching record does not prove the current live picture or HUD.
.EXAMPLE
.\Test-ReclaimerDisplay.ps1 -Width 1050 -Height 1680
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1, 16384)][int]$Width,
    [Parameter(Mandatory)][ValidateRange(1, 16384)][int]$Height,
    [string]$DataDirectory = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Project Reclaimer')
)

$ErrorActionPreference = 'Stop'
$expected = '{0}x{1}' -f $Width, $Height
$scene = $null
$backBuffer = $null
$loggedTime = $null
$logModified = $null
$displayMode = $null
$renderResolution = $null

try {
    $settings = Get-Content -LiteralPath (Join-Path $DataDirectory 'settings.json') -Raw | ConvertFrom-Json
    if ($null -eq $settings.graphics) { throw 'Missing graphics settings.' }
    # Emit only known preference values. Never echo unknown configuration text.
    if ($settings.graphics.display_mode -in @('borderless', 'windowed', 'exclusive_fullscreen')) {
        $displayMode = $settings.graphics.display_mode
    }
    if ($settings.graphics.render_resolution -in @('native', '1280x720', '1600x900', '1920x1080', '2560x1440', '3840x2160')) {
        $renderResolution = $settings.graphics.render_resolution
    }
    $logPath = Join-Path $DataDirectory 'Logs/client.log'
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        $logModified = (Get-Item -LiteralPath $logPath).LastWriteTimeUtc.ToString('o')
        $pattern = '^(\d{2}:\d{2}:\d{2}\.\d{3}) Live rendering resolution: scene=(\d{1,5}x\d{1,5}), back-buffer=(\d{1,5}x\d{1,5})\.$'
        # Get-Content permits the live client to keep writing its log.
        Get-Content -LiteralPath $logPath -ReadCount 256 | ForEach-Object {
            foreach ($line in $_) {
                if ($line -cmatch $pattern) {
                    $loggedTime = $Matches[1]
                    $scene = $Matches[2]
                    $backBuffer = $Matches[3]
                }
            }
        }
    }
}
catch {
    throw 'Could not read valid graphics settings and render-size records. No files were changed.'
}

[pscustomobject]@{
    ExpectedResolution = $expected
    DisplayMode = $displayMode
    RenderResolution = $renderResolution
    NativeFullscreenSelected = ($displayMode -in @('borderless', 'exclusive_fullscreen') -and $renderResolution -eq 'native')
    LastLoggedScene = $scene
    LastLoggedBackBuffer = $backBuffer
    LastLoggedTime = $loggedTime
    LogLastModifiedUtc = $logModified
    LastLoggedSizeMatches = ($scene -eq $expected -and $backBuffer -eq $expected)
    EvidenceLimit = 'Historical log snapshot only. Check the live Graphics page and picture. HUD placement is not tested.'
}

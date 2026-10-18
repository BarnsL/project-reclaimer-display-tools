<#
.SYNOPSIS
Prepares an experimental portrait HUD and Guardian scenario in an isolated H3EK copy.
.DESCRIPTION
Requires the reviewed stock HUD tag and a workspace marker. Uses H3EK's own
tag commands. Does not compile, install or change the running game.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$KitPath,
    [ValidateRange(640, 8192)][int]$Width = 1050,
    [ValidateRange(640, 8192)][int]$Height = 1680
)
$ErrorActionPreference = 'Stop'
if ($Height -le $Width) { throw 'This prototype requires a portrait viewport.' }
function Assert-NoReparsePath([string]$Path) {
    $part = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    while ($part) {
        if (Test-Path -LiteralPath $part) {
            if ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Workspace isolation failed: a relevant path contains a reparse point.'
            }
        }
        $parent = Split-Path -Parent $part
        if ($parent -eq $part) { break }
        $part = $parent
    }
}
Assert-NoReparsePath $KitPath
$kit = (Get-Item -LiteralPath $KitPath).FullName.TrimEnd('\')
if ($kit -match '(?i)[\\/]steamapps[\\/]' -or
    -not (Test-Path -LiteralPath (Join-Path $kit '.portrait-hud-workspace') -PathType Leaf)) {
    throw 'Use an isolated kit copy with a .portrait-hud-workspace marker, outside Steam libraries.'
}
$tool = Join-Path $kit 'tool_fast.exe'
$source = Join-Path $kit 'tags/ui/chud/globals.chud_globals_definition'
$scenarioSource = Join-Path $kit 'tags/levels/multi/guardian/guardian.scenario'
$scenarioTarget = Join-Path $kit 'tags/levels/portrait_hud/portrait_guardian.scenario'
foreach ($path in @($tool, $source, $scenarioSource, $scenarioTarget, (Join-Path $kit '.portrait-hud'))) {
    Assert-NoReparsePath $path
}
$baselineHash = '5CCE50E9129B66CEE2C46CE02C65B2F5DBB2CEA314D714CD968085C21E00D1BE'
if (-not (Test-Path -LiteralPath $tool -PathType Leaf) -or
    -not (Test-Path -LiteralPath $scenarioSource -PathType Leaf)) { throw 'Finish extracting the isolated H3EK before preparing the prototype.' }
if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $baselineHash) {
    throw 'The HUD tag is modified or from an unreviewed build. Use a fresh kit copy or restore the verified backup.'
}
if (Test-Path -LiteralPath $scenarioTarget) { throw 'The prototype scenario already exists. Refusing to overwrite it.' }

$virtualHeight = [int][math]::Round(1280.0 * $Height / $Width)
$radarY = $virtualHeight - 59
$runName = [guid]::NewGuid().ToString('N')
$run = Join-Path $kit ('.portrait-hud/' + $runName)
New-Item -ItemType Directory -Path $run | Out-Null
$candidateRelative = 'ui\chud\portrait_candidate_' + $runName + '.chud_globals_definition'
$candidate = Join-Path (Join-Path $kit 'tags') $candidateRelative
$baselineXml = Join-Path $run 'baseline.xml'
$candidateXml = Join-Path $run 'candidate.xml'
$backup = Join-Path $run 'original-globals.chud_globals_definition'
$script:toolStep = 0

function Invoke-KitTool([string[]]$ToolArguments) {
    $script:toolStep++
    $quoted = foreach ($arg in $ToolArguments) {
        if ($arg.Contains('"')) { throw 'Unexpected quote in a tool argument.' }
        '"' + $arg + '"'
    }
    $p = Start-Process -FilePath $tool -WorkingDirectory $kit -ArgumentList $quoted -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $run ("step-$script:toolStep.out")) `
        -RedirectStandardError (Join-Path $run ("step-$script:toolStep.err"))
    try {
        $p.PriorityClass = 'BelowNormal'
        if (-not $p.WaitForExit(30000)) { $p.Kill(); $p.WaitForExit(); throw 'H3EK command timed out. The original HUD tag was not replaced.' }
        if ($p.ExitCode -ne 0) { throw 'H3EK command failed. Inspect the private workspace logs.' }
    }
    finally { $p.Dispose() }
}

Copy-Item -LiteralPath $source -Destination $candidate
Invoke-KitTool @('export-tag-to-xml', $source, $baselineXml)
for ($skin = 0; $skin -lt 3; $skin++) {
    $field = "chud_globals_definition_struct_definition[0].skins[$skin].curvature infos[0]."
    Invoke-KitTool @('patch-tag-field', $candidateRelative, ($field + 'virtual height'), [string]$virtualHeight)
    Invoke-KitTool @('patch-tag-field', $candidateRelative, ($field + 'sensor origin'), ("55,$radarY"))
}
Invoke-KitTool @('export-tag-to-xml', $candidate, $candidateXml)
& (Join-Path $PSScriptRoot 'Test-PortraitHudTagXml.ps1') -BaselineXml $baselineXml -CandidateXml $candidateXml -Width $Width -Height $Height

# Stage the scenario, then publish both files with bounded rollback on failure.
$stagedScenario = Join-Path $run 'portrait_guardian.scenario'
[IO.File]::Copy($scenarioSource, $stagedScenario, $false)
$scenarioHash = (Get-FileHash -LiteralPath $stagedScenario -Algorithm SHA256).Hash
$candidateHash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash
New-Item -ItemType Directory -Path (Split-Path -Parent $scenarioTarget) -Force | Out-Null
$scenarioPublished = $false
$tagReplaced = $false
try {
    foreach ($path in @($source, $candidate, $backup, $scenarioTarget)) { Assert-NoReparsePath $path }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $baselineHash) {
        throw 'The original tag changed during preparation. Refusing to replace it.'
    }
    [IO.File]::Move($stagedScenario, $scenarioTarget)
    $scenarioPublished = $true
    [IO.File]::Replace($candidate, $source, $backup)
    $tagReplaced = $true
    if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -cne $baselineHash) {
        throw 'Backup verification failed.'
    }
}
catch {
    if ($tagReplaced) {
        Assert-NoReparsePath $source
        Assert-NoReparsePath $backup
        if ((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -cne $baselineHash) {
            throw 'The backup is not the verified original. All files were preserved for manual recovery.'
        }
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $candidateHash) {
            throw 'The tag changed again after replacement. Backup and scenario were preserved for manual recovery.'
        }
        $restore = Join-Path $run 'restore-globals.chud_globals_definition'
        [IO.File]::Copy($backup, $restore, $false)
        if ((Get-FileHash -LiteralPath $restore -Algorithm SHA256).Hash -cne $baselineHash) {
            throw 'The restore copy failed verification. All files were preserved for manual recovery.'
        }
        [IO.File]::Replace($restore, $source, (Join-Path $run 'rejected-globals.chud_globals_definition'))
        if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne $baselineHash) {
            throw 'Restoration could not be verified. The backup was preserved for manual recovery.'
        }
    }
    if ($scenarioPublished) {
        Assert-NoReparsePath $scenarioTarget
        if ((Get-FileHash -LiteralPath $scenarioTarget -Algorithm SHA256).Hash -ceq $scenarioHash) {
            Remove-Item -LiteralPath $scenarioTarget
        }
        else { throw 'The scenario changed during preparation. It was preserved for manual recovery.' }
    }
    throw 'Preparation failed; published changes were rolled back. Private candidate files and logs were retained.'
}
[pscustomobject]@{
    Viewport = "$Width`x$Height"
    VirtualHud = "1280x$virtualHeight"
    ChangedFields = 6
    Scenario = 'levels/portrait_hud/portrait_guardian'
    BackupRelativePath = '.portrait-hud/' + $runName + '/original-globals.chud_globals_definition'
    Status = 'Tags prepared and verified. Compile and test the map before claiming a HUD fix.'
}

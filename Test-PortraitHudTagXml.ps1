[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaselineXml,
    [Parameter(Mandatory)][string]$CandidateXml,
    [ValidateRange(640, 8192)][int]$Width = 1050,
    [ValidateRange(640, 8192)][int]$Height = 1680
)
$ErrorActionPreference = 'Stop'
if ($Height -le $Width) { throw 'This prototype requires a portrait viewport.' }
$virtualHeight = [int][math]::Round(1280.0 * $Height / $Width)
$expected = New-Object Xml.XmlDocument
$expected.XmlResolver = $null
# This H3EK build exports legacy Windows-1252 tag text without an encoding declaration.
$encoding = [Text.Encoding]::GetEncoding(1252)
$expected.LoadXml([IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($BaselineXml), $encoding))
$candidate = New-Object Xml.XmlDocument
$candidate.XmlResolver = $null
$candidate.LoadXml([IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CandidateXml), $encoding))
if ($expected.tag.group_tag -cne 'chgd' -or $candidate.tag.group_tag -cne 'chgd') { throw 'Expected CHUD globals XML.' }
$skins = $expected.SelectNodes('/tag/block[@name="skins"]/element')
if ($skins.Count -ne 3) { throw 'Expected three stock HUD skins.' }
foreach ($skin in $skins) {
    $layout = $skin.SelectSingleNode('block[@name="curvature infos"]/element[@index="0"]')
    if ($null -eq $layout -or
        $layout.SelectSingleNode('field[@name="res flags"]').value -cne '1' -or
        $layout.SelectSingleNode('field[@name="virtual width"]').value -cne '1280' -or
        $layout.SelectSingleNode('field[@name="virtual height"]').value -cne '720' -or
        $layout.SelectSingleNode('field[@name="sensor origin"]').value -cne '55,661') {
        throw 'Stock HUD layout differs from the reviewed prototype baseline.'
    }
    $layout.SelectSingleNode('field[@name="virtual height"]').SetAttribute('value', [string]$virtualHeight)
    $layout.SelectSingleNode('field[@name="sensor origin"]').SetAttribute('value', ('55,' + ($virtualHeight - 59)))
}
# Exported tag identity follows its file name. All fields must otherwise match.
$expected.tag.SetAttribute('id', $candidate.tag.id)
if ($expected.OuterXml -cne $candidate.OuterXml) {
    throw 'HUD tag verification failed: expected only portrait height and radar Y changes in the three fullscreen layouts.'
}
Write-Output "PASS: three fullscreen HUD layouts use 1280 x $virtualHeight; only virtual height and radar Y changed. Live placement remains unverified."

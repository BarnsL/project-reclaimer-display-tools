$ErrorActionPreference = 'Stop'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('portrait-xml-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
$baseline = Join-Path $fixture 'baseline.xml'
$candidate = Join-Path $fixture 'candidate.xml'
$checker = Join-Path $PSScriptRoot 'Test-PortraitHudTagXml.ps1'
function MustFail([scriptblock]$Action) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    if (-not $failed) { throw 'Unexpected acceptance of altered or unsupported HUD data.' }
}
try {
    # Synthetic fields only. No exported game content is included.
    $skin = '<element><block name="curvature infos"><element index="0"><field name="res flags" value="1"/><field name="virtual width" value="1280"/><field name="virtual height" value="720"/><field name="sensor origin" value="55,661"/><field name="unrelated" value="unchanged"/></element></block></element>'
    $stock = '<tag group_tag="chgd" id="original"><block name="skins">' + ($skin * 3) + '</block></tag>'
    [IO.File]::WriteAllText($baseline, $stock)
    $portrait = $stock.Replace('id="original"', 'id="candidate"').Replace('value="720"', 'value="2048"').Replace('55,661', '55,1989')
    [IO.File]::WriteAllText($candidate, $portrait)
    & $checker -BaselineXml $baseline -CandidateXml $candidate | Out-Null
    [IO.File]::WriteAllText($candidate, $portrait.Replace('unchanged', 'changed'))
    MustFail { & $checker -BaselineXml $baseline -CandidateXml $candidate }
    [IO.File]::WriteAllText($candidate, $stock)
    MustFail { & $checker -BaselineXml $baseline -CandidateXml $candidate }
    [IO.File]::WriteAllText($candidate, $portrait.Replace('55,1989', '55,661'))
    MustFail { & $checker -BaselineXml $baseline -CandidateXml $candidate }
    [IO.File]::WriteAllText($candidate, $portrait)
    MustFail { & $checker -BaselineXml $baseline -CandidateXml $candidate -Width 1920 -Height 1080 }
    [IO.File]::WriteAllText($baseline, $stock.Replace('value="1280"', 'value="1279"'))
    MustFail { & $checker -BaselineXml $baseline -CandidateXml $candidate }
    Write-Output 'PASS: portrait fields accepted; unrelated edits, stock layout, wrong radar, landscape and unknown baseline rejected.'
}
finally {
    $resolved = [IO.Path]::GetFullPath($fixture)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolved) -match '^portrait-xml-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

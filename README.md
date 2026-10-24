# Project Reclaimer display tools

Independent display troubleshooting for the Windows Project Reclaimer client.
This repository contains no game source, binaries, assets, profiles, or logs.

## Status

Tested with Project Reclaimer 0.9.18 on Windows, on a 1050 x 1680 portrait display.
Reapplying the native rendering resolution corrected a stretched game picture
without restarting the game. The existing Graphics page displayed the correct
dimensions, and new log entries confirmed both the scene and back buffer sizes.

**HUD corner placement remains unverified in gameplay.** A separate Guardian
test map was compiled and installed locally. Its three fullscreen HUD layouts
contain a 1280 x 2048 virtual canvas and a sensor origin of 55,1989 for the
1050 x 1680 display. Those values were read back from the installed map.
The supplied campaign screenshot still shows the original central HUD.
Installing this package does not change stock campaigns or other maps.

A separate, version-checked portrait client prototype is now available through
`portrait_client.py`. It targets the client's built-in HUD adjustment and the
fullscreen Default startup resolution. A fresh startup verified 1050 x 1680.
The canvas-height and safe-frame attempts failed visibly. The current candidate
corrects the engine's portrait viewport crop and is awaiting its live test.
See **Build the experimental portrait client**.

Compatibility check, 2026-10-23: the builder supports only client 0.9.18.
Client 0.9.21 has a different executable layout and is deliberately rejected.
Do not apply the old offsets to a newer client or replace an updated install
with this prototype. The remaining gates are a visible stock-campaign HUD test,
an explicit in-game resolution change followed by a restart, and a separately
reviewed port to the current client.

The preparation script edits HUD tags only in a marked, isolated editing-kit
copy. It does not patch the client executable, process memory, stock game maps,
or the Steam editing kit. There is no new in-game HUD setting.

Project Reclaimer's [official repository](https://github.com/ProjectReclaimer/project-reclaimer-releases)
publishes releases only. This project is not affiliated with its developers.

## Recover the portrait rendering resolution

Keep the game on the intended monitor throughout these steps. Use the existing
**Settings > Graphics** page, including when the game is already running.

1. Select **Borderless fullscreen** for Display mode.
2. If Rendering resolution already says **Default** but the picture is stretched,
   select **1280 x 720**, choose **Apply changes**, then **Keep changes**.
   This temporary selection can look stretched or blurred.
3. Select **Default** again. Before applying, check that the right panel's
   **Draws at** value matches the portrait display, for example **1050 x 1680**.
4. Choose **Apply changes**, then **Keep changes** within the confirmation timer.
   If the display becomes unusable, let the timer restore the prior setting.
5. Confirm **Draws at 1050 x 1680** and inspect the game picture. The radar,
   characters and world should no longer be stretched. HUD edge placement is
   a separate check and is not fixed by these steps.

Do not select a fixed landscape render size as the final setting. In fullscreen,
the saved window width and height are not the rendering resolution. A saved
1280 x 720 window size can coexist with correct native portrait rendering.

The [official settings guide](https://projectreclaimer.dev/play#settings)
documents native fullscreen rendering and display-change confirmation.

## Read-only checker

Run with Windows PowerShell 5.1 or PowerShell 7. No packages are required.

```powershell
.\Test-ReclaimerDisplay.ps1 -Width 1050 -Height 1680
```

The checker reads `settings.json` and `Logs/client.log` under the current user's
Documents / My Games / Project Reclaimer folder. It prints only known display
preference values, dimensions and timestamps. It does not read `profile.json`,
upload data, modify files, launch the game, or change Windows display settings.

Check `NativeFullscreenSelected` and `LastLoggedSizeMatches`. A missing record
returns unknown dimensions and a false match. A matching log record is historical
evidence, not proof that a running game still has that state. Compare the record
time and check the live Graphics page. The script does not test HUD placement.

For an alternate data folder, pass `-DataDirectory` locally. Do not publish that
folder. Never share `profile.json` or `stats-key.json`; the client identifies them
as private-key files. Raw logs can contain player and server identifiers.

Run the regression check:

```powershell
.\Test-ReclaimerDisplay.Tests.ps1
```

## Observed resolution sequence

The following summary contains only render dimensions, not copied game logs:

| Stage | Scene | Back buffer |
| --- | --- | --- |
| Before reapplying the setting | 1920 x 1080 | 1920 x 1080 |
| Temporary fixed setting | 1280 x 720 | 1280 x 720 |
| Default reapplied on portrait display | 1050 x 1680 | 1050 x 1680 |

The client retained landscape render dimensions after it was on the portrait
monitor. Reapplying Default caused fresh portrait render dimensions. A restart
or future monitor move has not been tested, so this is a recovery procedure,
not a permanent fix for monitor-change handling.

## Publication boundary

Only this README, authored preparation/checking/packaging scripts, their
synthetic tests and `.gitignore` are tracked.
The ignore file rejects other files by default. There are no copied game assets,
binaries, extracted sections, profiles, credentials, personal paths or raw logs.
Commit identity uses the public account name and the placeholder `redacted`.

## Remaining HUD work

The documented Game options page exposes reticle and visor preferences, but no
native radar, ammo or shield edge-anchor control was found. The source is not
published. An upstream renderer change or a separately developed, verified
extension would be needed to expose such a control in the existing settings UI.
No such change has been implemented or verified here.

## HUD mod assessment

Research date: 2026-10-17. Target client: 0.9.18. The native-client section is
a design assessment. The map prototype described below has been compiled and
installed locally, but its visible HUD result is still pending.

### Recommended route

Implement an optional **Screen edges** layout in the client's native HUD
renderer. Expose **HUD layout: Original / Screen edges** under
**Settings > Game options > HUD**. These are proposed controls; the released
client does not currently expose them. Use each player's actual viewport and
keep the existing widget size and proportions.

| Widget | Requested anchor |
| --- | --- |
| Radar / motion sensor | Bottom left |
| Grenades and equipment | Top left |
| Shield / health bar | Top center |
| Weapon icons and ammunition | Top right |
| Aiming reticle | Existing aim point, unchanged |
| World-space markers and objectives | Existing projection, unchanged |

Retain a small safe inset so elements are not clipped at the display edge.
Move the anchor positions, not the entire HUD image. A single vertical stretch
would distort the widgets and could move the reticle away from the aim point.

The observed portrait HUD occupies a central landscape-shaped band despite
correct scene and back-buffer dimensions. That suggests a viewport/layout
transform issue. The precise transform has not yet been proven from source or
an instrumented runtime test; a guessed binary offset is not a verified fix.

### Why the existing Mods page is not a global HUD plug-in loader

The [official mod documentation](https://projectreclaimer.dev/play#mods) states
that mods contain map files and that Reclaimer does not execute program code
from them. The page supports map/campaign packages and character content. It
does not document a general client plug-in interface or a way for a mod to add
native settings controls.

| Route | Scope and limitation | Decision |
| --- | --- | --- |
| Native client change | Can apply the layout across maps and expose a real settings control. Source access or upstream implementation is needed. | Preferred release path |
| Version-specific local patch | Could prototype a proven renderer change using the owner's installed client. Update compatibility and online acceptance would need testing. | Experimental fallback only |
| Map/tag mod | May alter HUD tags within packaged maps. It is not a verified global override for stock maps or other authors' mods. | Limited proof of concept |
| Megalo game-mode script | Provides its own text and bar widgets, not relocation of the native radar, shields or weapon HUD. Its script canvas is centered and aspect-preserving. | Does not meet this request |

The [Megalo HUD reference](https://projectreclaimer.dev/megalo#hud-widgets)
defines a centered 1280 x 720 script canvas and limits widget positions to that
canvas. Its per-widget anchors refer to those scripted widgets. A `bottom_left`
anchor there must not be presented as a way to move the native motion sensor to
the physical corner of a portrait monitor.

[Microsoft's Halo 3 Editing Kit guide](https://learn.microsoft.com/en-us/halo-master-chief-collection/h3/quickstart/quickstartoverview)
documents tag editing and building maps. That supports investigating a separate
map-based prototype, but does not establish that Reclaimer accepts a global HUD
tag override. H3EK is now installed and was used to build the local prototype.

### Prototype and release gates

1. Prove which native transform controls the edge widgets. Separate that path
   from the reticle, visor, world markers and scripted HUD.
2. Test an isolated, reversible prototype in a local game. Do not replace the
   normal launcher or modify the active game while investigating.
3. Verify the radar at bottom left and the other requested groups at the top
   on 1050 x 1680 and 1080 x 1920. Check that 1920 x 1080 stays correct.
4. Verify on foot, while aiming, in vehicles, after respawn and after changing
   maps. For split screen, anchor to each player's viewport.
5. Verify the settings control, saving, relaunch and complete rollback. Treat
   online compatibility as unverified until tested without changing security
   or anti-cheat behavior.
6. Publish only authored code, tests and installation instructions. Exclude
   game binaries, extracted sections, copyrighted map contents, private profiles,
   machine paths and raw logs. A local patch must check the exact client version
   and original bytes and refuse unknown versions.

The public repository contains the recovery guide, read-only display diagnostics,
isolated HUD-tag preparation, XML verification and a map-package helper.
An experimental native portrait client builder is also included. It does not
add an in-game toggle. Compiled maps and generated clients stay local; neither
they nor extracted game tags are distributed here.

## Build the experimental portrait client

This is an experimental local client modification, not a map package. It can
apply to stock layouts across maps because it uses Reclaimer's checked engine
patching path. HUD placement, online compatibility, split screen and
landscape use remain unverified. Use a local test before relying on it.

The builder accepts only the official Windows x64 0.9.18 client with SHA-256:

```text
a8d3a37ad27e31abc09d009a94210470976ecefb34908a9fb8e1a245f4924910
```

It also requires the installed Halo 3 engine with SHA-256:

```text
b209d8454b12dc77e54ccd2c9924ec8d44b8619d21cf98e36ffaf601e67efb63
```

It writes a new executable and refuses an existing destination, linked paths,
unknown versions or changed original instructions. It does not replace the
normal client, edit settings, change stock maps or attach to a running process.
Keep the generated client outside Git. Python 3.11 or newer is required.

```powershell
python .\test_portrait_client.py
python .\portrait_client.py --source "$originalClient" --engine "$halo3Engine" --output "$newClient" --width 1050 --height 1680
```

Set the three local paths yourself. The output directory must already exist.
Launch the new copy for testing. Returning to the normal executable restores
normal client behavior; no Steam files need restoration.

Changes in the prototype:

- Fullscreen **Default** uses 1050 x 1680 at startup. The original startup path
  selects the current monitor before a later move to the portrait display.
- Explicit in-game presets, such as 1920 x 1080, keep their original startup
  branches. The builder does not rewrite their saved settings. Windowed Default
  also keeps the original startup behavior.
- The engine no longer cuts a narrow viewport into a centered 16:9 strip.
  Its narrow-viewport branch recalculates virtual Y coordinates from the actual
  viewport aspect and preserves the radar's bottom inset. Widget pixel scale
  remains proportional in both axes. The landscape branch is unchanged.
- The client applies the engine change before gameplay through its existing
  checked patcher, including byte comparison, page-protection restoration and
  instruction-cache flushing. A failed patch follows the original startup
  error path. Stock files and HUD tags on disk remain untouched.
- The new code has a matching Windows runtime-function/unwind entry. For the
  default dimensions, the generated client differs in 338 bytes within seven
  reviewed ranges. Unknown client or engine hashes are refused.

The native startup selector has one direct caller in the reviewed image. The
builder changes its Default branch and leaves all fixed-size branches intact.
Disassembly checks confirm the generated loop, jump targets, error return and
stack metadata. Scalar-instruction tests cover portrait and square viewport
math, widget proportions and the radar inset. These are static checks; they
do not establish correct rendered positions or working gameplay.

The first native test changed virtual height to 2048. Actual campaign gameplay
showed flattened widgets in the original central band. That method was rejected.
The second attempt restored proportions but its safe-frame change did not move
the HUD. Engine inspection then identified the explicit 16:9 crop and its
virtual-coordinate normalization. The current candidate corrects that branch.
Its live HUD test is pending. A fresh start of candidate 3 on 2026-10-24 verified
1050 x 1680 for both the scene and back buffer before any in-game resolution
change. The candidate remained running and responsive. Startup acceptance does
not establish the positions of the in-game HUD widgets.

Before calling this fixed, verify a fresh portrait startup, radar bottom-left,
status groups across the top, reticle/world-marker alignment, and a saved
explicit resolution surviving a restart. A client update requires a new source
review; the builder refuses another release rather than guessing its offsets.

## Build the map-based HUD prototype

This is the earlier investigation route. Its virtual-height edits failed in
the direct client test. Do not combine the old Guardian prototype with the
current native candidate, and do not treat it as a released working HUD mod.

Start with one independently named test map. The first runtime test must prove
that Reclaimer honors the edited HUD tags. It might apply its own HUD transform
after loading those tags. Do not build a full campaign pack before that test.

1. Install [Halo 3 Mod Tools - MCC](https://store.steampowered.com/app/1695791/)
   from the Steam Library's Tools category. Ownership of Halo 3 in MCC is required.
   Extract the supplied tags with the kit's extraction workflow. Keep its stock
   source tags intact and work from copies. Allow space for extracted tags and
   compiled maps as well as the initial download.
2. Make a complete, independent copy of the extracted kit outside Steam libraries.
   Do not link its tag directory to the original. In that copy, create an empty
   `.portrait-hud-workspace` marker. Set `$kit` to that copy's directory, then run:

   ```powershell
   .\Prepare-PortraitHud.ps1 -KitPath $kit -Width 1050 -Height 1680
   ```

   The script checks the reviewed stock globals tag hash, refuses linked paths
   and an existing prototype scenario, and uses the kit's own tag commands.
   It changes only virtual height and sensor Y in each of the three fullscreen
   layouts. It keeps an original-tag backup under `.portrait-hud` and copies
   Guardian to `levels/portrait_hud/portrait_guardian`.

   A full XML comparison checks that no other exported fields changed. A failure
   retains its private logs and candidate for inspection. Never remove guards
   to accept another kit version. Restore the isolated copy or use a fresh copy
   after reviewing a changed baseline. Do not reuse this modified kit for normal
   landscape map builds.

   The community [Halo 3 MCC CHDT schema](https://github.com/XboxChaos/Assembly/blob/dev/src/Assembly/Plugins/Halo3MCC/chdt.xml)
   identifies placement anchors, origin offsets and widget scale. Its grenade
   anchors also select grenade-specific inputs, so do not replace all of them
   with a generic top-left anchor. Preserve inherited child placement and adjust
   the appropriate parent or offset. The [CHGD schema](https://github.com/XboxChaos/Assembly/blob/dev/src/Assembly/Plugins/Halo3MCC/chgd.xml)
   identifies virtual dimensions, safe-frame values and sensor origin. Inspect
   those first to distinguish the central viewport band from per-widget offsets.
3. Compile that scenario with the official tool. From the mod tools directory:

   ```powershell
   .\tool_fast.exe build-cache-file levels\portrait_hud\portrait_guardian x64
   ```

4. Package the resulting map with the helper in this repository. Replace
   `$kit` with the installed mod tools directory in your local terminal:

   ```powershell
   .\New-ReclaimerModPackage.ps1 `
     -MapFile (Join-Path $kit 'maps/portrait_guardian.map') `
     -Scenario 'levels/portrait_hud/portrait_guardian' `
     -OutputDirectory '.local/Portrait-HUD-Test'
   ```

   The helper requires an existing `.map` with the observed MCC cache header
   (`daeh`, version 13). It generates new package/map IDs, uses relative content
   paths, writes UTF-8 JSON without a BOM, and refuses an existing output folder.
   It does not edit tags, compile maps, inspect dependencies, or verify gameplay.
   A failed copy can leave a partial output; it never replaces an existing mod.

   ```text
   Portrait-HUD-Test/
     ModInfo.json
     multiplayer/portrait_guardian.json
     maps/portrait_guardian.map
   ```

5. Once built, copy the package folder to the current user's Documents /
   My Games / Project Reclaimer / Mods folder. In Reclaimer choose Refresh in
   Host Game, select the separately named test map, and start a local game.
   Confirm it appears in Settings > Mods. Test the actual HUD placement, reticle,
   vehicles and respawns at the portrait resolution. Appearance in the Mods list
   is not proof that the HUD changed.
6. If that test passes, expand to the desired maps. A packaged-map HUD mod is
   limited to its maps; it is not a verified override for stock campaigns,
   arbitrary servers or other authors' mods. An in-game HUD-layout toggle still
   needs a separate native implementation. Workshop upload is not needed for
   local Reclaimer testing and has not been performed.

The map package format follows [Microsoft's Excession folder documentation](https://learn.microsoft.com/en-us/halo-master-chief-collection/excession/setup/folderstructure)
and the structure of an installed Reclaimer mod. The builder command follows
[Microsoft's cache-building guide](https://learn.microsoft.com/en-us/halo-master-chief-collection/h3/quickstart/process/step9).
Package metadata is source material we can publish. The kit, extracted game
tags and compiled game maps stay outside Git. The helper's fixtures contain only
synthetic headers and are not playable maps.

Run its tests with either Windows PowerShell 5.1 or PowerShell 7:

```powershell
.\New-ReclaimerModPackage.Tests.ps1
```

## Current verification boundary

The installed local package is named **Portrait HUD - Guardian**. Its compiled
scenario is `levels/portrait_hud/portrait_guardian`. Direct inspection found
three portrait layout records and no matching stock layout records in its tag
section. This verifies packaged data, not the renderer or gameplay.

The next required test is **Host Game > Portrait HUD - Guardian** in a local
session. A screenshot of a stock campaign does not test this package. Confirm
1050 x 1680 in the live rendering settings, then check radar bottom-left,
grenades top-left, shields top-center and ammunition top-right. Check that the
reticle and world markers still align with the scene. Do not publish a claim of
a working HUD mod until that test passes.

Run the additional checks:

```powershell
.\Prepare-PortraitHud.Tests.ps1
.\Test-PortraitHudTagXml.Tests.ps1
```

The first creates and removes an owned temporary junction to test isolation.
Use a shell that permits that test. The second uses synthetic XML only.
Keep the kit, backups, exports and compiled map outside the public repository.

# Project Reclaimer display tools

Independent display troubleshooting for the Windows Project Reclaimer client.
This repository contains no game source, binaries, assets, profiles, or logs.

## Status

Tested with Project Reclaimer 0.9.18 on Windows, on a 1050 x 1680 portrait display.
Reapplying the native rendering resolution corrected a stretched game picture
without restarting the game. The existing Graphics page displayed the correct
dimensions, and new log entries confirmed both the scene and back buffer sizes.

**HUD corner placement remains unresolved.** The native health bar, ammo and
radar can remain inside a central area on a portrait display. This repository
does not reposition those widgets or add an in-game HUD setting. The reticle
should remain at the aiming point. No game files or process memory are patched.

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

Only this README, the checker, the map packager, their synthetic tests and `.gitignore` are tracked.
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

Research date: 2026-10-17. Target client: 0.9.18. This is a design assessment,
not an installable HUD mod or a tested binary patch.

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
tag override. H3EK was not found in the checked local Steam common directories.

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

The public repository contains a recovery guide, read-only diagnostics and a
map-package helper. The native HUD change, an in-game toggle and a playable HUD
mod remain unimplemented.

## Build the map-based HUD prototype

Start with one independently named test map. The first runtime test must prove
that Reclaimer honors the edited HUD tags. It might apply its own HUD transform
after loading those tags. Do not build a full campaign pack before that test.

1. Install [Halo 3 Mod Tools - MCC](https://store.steampowered.com/app/1695791/)
   from the Steam Library's Tools category. Ownership of Halo 3 in MCC is required.
   Extract the supplied tags with the kit's extraction workflow. Keep its stock
   source tags intact and work from copies. Allow space for extracted tags and
   compiled maps as well as the initial download.
2. Copy a small stock scenario into a separate namespace, for example
   `levels/portrait_hud/portrait_guardian`. Inspect the scenario's actual HUD tag
   references in Guerilla. Make separate HUD tag copies for the prototype.
   Adjust the radar's lower-left placement and the upper status groups without
   changing reticle or world-marker behavior. Exact tag edits are not yet known;
   they must be established against the installed kit and tested in Reclaimer.

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

Current build gate: Halo 3 Mod Tools and its extracted tags are required before
the HUD edits and first playable prototype can be produced. No test map has yet
been built or installed.

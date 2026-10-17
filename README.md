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

Only this README, the checker, its synthetic tests and `.gitignore` are tracked.
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

The public repository remains a recovery guide and read-only diagnostic tool.
The native HUD change, an in-game toggle and a loadable mod remain unimplemented.

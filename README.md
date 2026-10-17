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

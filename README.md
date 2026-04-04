# Ray's Macro Patch Installer Guide

This guide explains how to install Ray's TadSync patch onto almost any Natro Macro version.
## If you are confuse dm @DefinetlyNotRay on discord for help!

## What this patch adds

- Field Following / TadSync
- StatMonitor Editor
- Blue Booster Interrupt
- Sticker Stack Interrupt
- Glitter Extend
- Pre-Glitter
- Force Hourlies (?hr)
- Mondo Interupt
- Boosted Enzyme Only
- StatMonitor theme + extra rows/assets
- AutoJelly / other Ray patch additions, depending on the patch files included (?yes, ?no)

## Requirements

- A working Natro Macro folder
- AutoHotkey v2
- Ray's patch files copied into that Natro folder

## Files you need to copy into the target Natro folder

Copy these from the patched build into the target Natro root:

- `patcher.ahk`
- `Extensions\`
- `patch_templates\`
- `Assets\`
- any other Ray patch assets that came with your build

At minimum, the important folders/files are:

- `patcher.ahk`
- `Extensions\tadsync_extension.ahk`
- `Extensions\tadsync_status_extension.ahk`
- `patch_templates\statmonitor_theme_main_patch.ahk`
- `patch_templates\statmonitor_theme_editor_patch.ahk`
- `patch_templates\statmonitor_theme_runtime_patch.ahk`
- `patch_templates\statmonitor_extra_bitmaps_patch.txt`

## Recommended install method

1. Start with a clean Natro Macro folder if possible.
2. Copy Ray's patcher and patch folders into the Natro root.
   -<img width="624" height="324" alt="image" src="https://github.com/user-attachments/assets/beab6e00-238c-4897-8eb7-d91d3fbd1cf7" />

4. Run `patcher.ahk`.
5. Let it patch the macro files.
6. Start Natro normally.
7. Check the `Extensions` tab to confirm the patch applied.

## If patching an already-patched Natro

You usually do **not** need a fresh `natro_macro.ahk`.

Ray's patcher upgrades the existing patched file in place.

That said:
- if the macro was heavily edited manually
- or patched by multiple older/custom patchers
- or the UI looks broken after patching

then starting from a cleaner base is safer.

## Important note

After patching:
- make sure the macro you launch is the patched one
- restart the macro fully after replacing files
- do not judge the result from an older running instance

x
## How to verify it worked

After launching Natro:

- the footer should show `Rays.v...`
- the `Extensions` tab should exist
- `Field Following` should be there
- `StatMonitor Editor` should be there
- extra Ray toggles should appear in `Extensions`

## If something does not update

Common reasons:

- wrong Natro folder was patched
- old macro instance was still running
- files were copied, but the patcher was not rerun
- the install is using a different `natro_macro.ahk` than expected

## Safe install advice

Before patching, back up:

- `submacros\natro_macro.ahk`
- `submacros\Status.ahk`
- `submacros\StatMonitor.ahk`
- `settings\nm_config.ini`

## Credits

Made by: @definetlynotray  
Inspired by @baspas

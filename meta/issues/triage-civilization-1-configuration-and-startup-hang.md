# Triage Civilization 1 Configuration And Startup Hang

## Summary

Civilization 1 initially reached its configuration flow but failed after startup choices because the runtime used FCB directory search calls that LainDOS did not implement. Narrow FCB `FindFirst`/`FindNext` support now lets the game reach visible gameplay.

## Requirements

- Build or document a local Civilization 1 repro image without committing proprietary game files.
- Capture serial output, framebuffer state, and the exact launch/configuration steps that reproduce the issue.
- Determine whether the configuration-menu corruption is console, keyboard, VGA/BIOS, filesystem, or program-loader related.
- Determine whether the startup hang shares a root cause with the configuration issue or is a separate runtime blocker.
- Add a focused regression or smoke script if a small DOS/API behavior explains the failure.

## Acceptance Criteria

- The issue has a repeatable launch/configuration repro and recorded failure signature.
- Civilization 1 reaches gameplay, or the remaining blocker is isolated with enough detail for a follow-up issue.
- Relevant regressions and `make test` pass after any implementation change.

## Resolution

- Reproduced from the local `vendor/sid-meiers-civilization-au.zip` floppy images by extracting generated files under `build/` only and launching `CIV` from a LainDOS image.
- The configuration menu renders readably in the current repro; after choices `1`, `1`, `1`, the pre-fix failure was an unhandled `INT 21h AH=11` followed by `EXC 06`.
- Implemented narrow `INT 21h AH=11h`/`AH=12h` FCB `FindFirst`/`FindNext` for current-directory 8.3 searches, including extended-FCB attribute masks, and added the `FCBFIND` regression.
- Post-fix Civilization reaches the title/menu path and visible new-game gameplay with no unhandled `INT 21h AH=` marker and no `EXC ` marker in the smoke output.
- Verification passed with focused regressions and the full `make test` ladder at `72/72`.

## Notes

- Reported symptoms: "configuration menu is all weird" and "hangs on start".
- Proprietary Civilization files are generated under `build/` for local repro only and are not tracked.
